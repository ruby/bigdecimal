# frozen_string_literal: true

# Experimental multipoint-evaluation version of the Lagrange interpolation
# used by BigMath.gamma, targeting full-digit x.
#
# The BSGS version in gamma.rb costs O(PREC^2 * polylog): every node needs a
# scalar multiplication against a full-precision power of x. This file evaluates
# the same barycentric sum with sqrt-size batches instead:
#   - The [sum_num, mult_num, den] triple of the BSM branch is lifted to
#     polynomials in the batch offset z. One triple tree describes all batches.
#   - Polynomial arithmetic runs on fixed-point coefficients via Kronecker
#     substitution onto Integer multiplication, so it needs quasi-linear Integer
#     multiplication (GMP-backed Ruby).
#   - The polynomials are evaluated at the arithmetic progression z = 0, mb,
#     2*mb, ... (currently by per-point Horner with small multipliers; a fast
#     Newton-basis transform can replace it later).
# Polynomial work is O(PREC^1.5 * polylog).
#
# The batch denominator values E(z) used in prod are derived from the same
# computed F2(z) used in sum (E = F2 * (x-A-z) / (B*I) with exact integer B, I),
# so the near-node cancellation between prod and sum stays exact, like the
# batch_prod reuse in the BSGS branch.

require 'bigdecimal/math/gamma'

module BigMath
  module Gamma
    module Multipoint # :nodoc:

      # :fast = remainder-tree multipoint evaluation (quasi-linear)
      # :horner = per-point Horner (simple; the only PREC^2 term of the pipeline,
      #           but with a machine-word-size constant)
      # :auto = :fast only when the batch count is large enough to win.
      # Measured crossover on GMP-backed Ruby is around m = 700 batches,
      # i.e. roughly 250000 digits of precision.
      FAST_EVAL_MIN_BATCHES = 700
      @eval_mode = :auto
      class << self
        attr_accessor :eval_mode
      end

      # ---------- Kronecker substitution convolution on Integer ----------

      # Packs signed coefficients as consecutive slot_hex*4-bit slots.
      # Negative coefficients are folded borrow-style into the next slot, so a
      # single hex-join suffices (no negative-part pack and giant subtraction).
      def self.pack_signed(coeffs, slot_hex)
        w = slot_hex * 4
        full = 1 << w
        borrow = 0
        strs = coeffs.map do |c|
          v = c + borrow
          if v < 0
            borrow = -1
            v += full
          else
            borrow = 0
          end
          v.to_s(16).rjust(slot_hex, '0')
        end
        n = strs.reverse!.join.to_i(16)
        borrow.zero? ? n : n - (1 << (w * coeffs.size))
      end

      # Splits n back into signed slot values with borrow propagation
      # (slots >= 2**(w-1) are negative), avoiding a giant bias addition.
      def self.unpack_signed(n, slot_hex, size)
        w = slot_hex * 4
        half = 1 << (w - 1)
        full = 1 << w
        neg = n.negative?
        s = (neg ? -n : n).to_s(16).rjust(slot_hex * size, '0')
        carry = 0
        out = Array.new(size) do |i|
          v = s[(size - 1 - i) * slot_hex, slot_hex].to_i(16) + carry
          if v >= half
            carry = 1
            v - full
          else
            carry = 0
            v
          end
        end
        out.map! {|v| -v } if neg
        out
      end

      # Convolution of signed Integer coefficient arrays.
      def self.convolve(a, b)
        out_size = a.size + b.size - 1
        if a.size < 16 || b.size < 16
          out = Array.new(out_size, 0)
          a.each_with_index {|c, i| b.each_with_index {|d, j| out[i + j] += c * d } }
          return out
        end
        max_a = 1
        a.each {|c| bits = c.abs.bit_length; max_a = bits if bits > max_a }
        max_b = 1
        b.each {|c| bits = c.abs.bit_length; max_b = bits if bits > max_b }
        w = max_a + max_b + out_size.bit_length + 2
        slot_hex = (w + 3) / 4
        prod = pack_signed(a, slot_hex) * pack_signed(b, slot_hex)
        unpack_signed(prod, slot_hex, out_size)
      end

      # ---------- fixed-point polynomials ----------
      # Represented as [coeffs, exp]: sum of coeffs[d] * 2**exp * z**d.
      # A single exp per polynomial (fixed-point): small coefficients keep less
      # relative precision, which only affects small contributions to the value.

      def self.fp_normalize(coeffs, exp, keep_bits)
        max = 0
        coeffs.each {|c| bits = c.abs.bit_length; max = bits if bits > max }
        s = max - keep_bits
        return [coeffs, exp] if s <= 0
        [coeffs.map {|c| c >> s }, exp + s]
      end

      def self.fp_mult(p1, p2, keep_bits)
        fp_normalize(convolve(p1[0], p2[0]), p1[1] + p2[1], keep_bits)
      end

      def self.fp_add(p1, p2, keep_bits)
        c1, e1 = p1
        c2, e2 = p2
        if e1 > e2
          c2 = c2.map {|c| c >> (e1 - e2) }
          e = e1
        elsif e2 > e1
          c1 = c1.map {|c| c >> (e2 - e1) }
          e = e2
        else
          e = e1
        end
        out = Array.new(c1.size > c2.size ? c1.size : c2.size, 0)
        c1.each_with_index {|c, i| out[i] += c }
        c2.each_with_index {|c, i| out[i] += c }
        fp_normalize(out, e, keep_bits)
      end

      # Multiplies an fp polynomial by an exact Integer-coefficient polynomial.
      def self.fp_mult_intpoly(p, ip, keep_bits)
        fp_normalize(convolve(p[0], ip), p[1], keep_bits)
      end

      # Exact Horner evaluation at an integer point. Returns the Integer mantissa;
      # the value is mantissa * 2**poly_exp.
      def self.fp_eval_int(poly, z)
        acc = 0
        poly[0].reverse_each {|c| acc = acc * z + c }
        acc
      end

      # ---------- fast evaluation at an arithmetic progression ----------
      # Classical remainder-tree multipoint evaluation. The subproduct moduli for
      # consecutive integer points are falling-factorial-type polynomials with
      # small exact Integer coefficients (about count * log2(count) bits), which
      # keeps the divisions well-scaled.

      def self.fp_neg(p)
        [p[0].map {|c| -c }, p[1]]
      end

      def self.fp_trunc(p, n)
        [p[0][0, n] || [0], p[1]]
      end

      def self.fp_mult_trunc(p1, p2, n, keep_bits)
        fp_normalize(convolve(p1[0], p2[0])[0, n], p1[1] + p2[1], keep_bits)
      end

      # Power series inverse to the given length, by Newton iteration.
      # The constant term of f must be exactly 1 (monic reversed modulus).
      def self.fp_inv_series(f, terms, keep_bits)
        y = [[1], 0]
        len = 1
        while len < terms
          len = 2 * len < terms ? 2 * len : terms
          fy = fp_mult_trunc(fp_trunc(f, len), y, len, keep_bits)
          y = fp_mult_trunc(y, fp_add([[2], 0], fp_neg(fy), keep_bits), len, keep_bits)
        end
        y
      end

      # Remainder of fp polynomial r modulo a monic exact-Integer polynomial
      # m_int (little-endian coefficient array), via reversal and a precomputed
      # power series inverse of the reversed modulus.
      def self.fp_rem(r, m_int, inv, keep_bits)
        dm = m_int.size - 1
        return r if r[0].size <= dm
        ql = r[0].size - dm
        qrev = fp_mult_trunc([r[0].reverse, r[1]], fp_trunc(inv, ql), ql, keep_bits)
        qm = fp_mult([qrev[0].reverse, qrev[1]], [m_int, 0], keep_bits)
        fp_trunc(fp_add(r, fp_neg(qm), keep_bits), dm)
      end

      # Tree of exact moduli prod{ t - k } over k = lo ... hi.
      # Leaf nodes are [modulus]; internal nodes are [modulus, left, right, nil, nil],
      # where the two trailing slots memoize the reversed-modulus inverses of the
      # children (shared by all evaluations against the same point set).
      def self.subproduct_tree(lo, hi)
        return [[-lo, 1]] if hi - lo == 1
        mid = (lo + hi) / 2
        left = subproduct_tree(lo, mid)
        right = subproduct_tree(mid, hi)
        [convolve(left[0], right[0]), left, right, nil, nil]
      end

      def self.eval_descend(r, node, keep_bits, out)
        if node.size == 1
          out << [r[0][0] || 0, r[1]]
          return
        end
        left = node[1]
        right = node[2]
        # A dividend has degree < deg(node modulus), so the inverse length needed
        # for division by one child is at most the degree of the other child.
        node[3] ||= fp_inv_series([left[0].reverse, 0], right[0].size - 1, keep_bits)
        node[4] ||= fp_inv_series([right[0].reverse, 0], left[0].size - 1, keep_bits)
        eval_descend(fp_rem(r, left[0], node[3], keep_bits), left, keep_bits, out)
        eval_descend(fp_rem(r, right[0], node[4], keep_bits), right, keep_bits, out)
      end

      # Values of poly at z = 0, stride, 2*stride, ..., (count-1)*stride.
      # Returns [mantissas, exp] with a shared exp.
      def self.fp_eval_points(poly, stride, count, keep_bits, tree = nil)
        sp = 1
        coeffs = poly[0].map {|c| v = c * sp; sp *= stride; v }
        scaled = fp_normalize(coeffs, poly[1], keep_bits)
        return [[scaled[0][0] || 0], scaled[1]] if count == 1

        tree ||= subproduct_tree(0, count)
        m_root = tree[0]

        r = scaled
        if scaled[0].size > count
          # Reduce blockwise: h = h_0 + h_1 * R + h_2 * R**2 + ... (mod M_root)
          # with R = t**count mod M_root. R has small coefficients (values of
          # t**count at the points are at most count**count), so the only wide
          # division is the final reduction of a degree < 2*count polynomial.
          root_inv = (tree[5] ||= fp_inv_series([m_root.reverse, 0], count, keep_bits))
          rpow = fp_rem([Array.new(count, 0) + [1], 0], m_root, root_inv, keep_bits)
          blocks = scaled[0].each_slice(count).map {|blk| [blk, scaled[1]] }
          acc = blocks[0]
          rp = rpow
          (1...blocks.size).each do |i|
            acc = fp_add(acc, fp_mult(blocks[i], rp, keep_bits), keep_bits)
            rp = fp_rem(fp_mult(rp, rpow, keep_bits), m_root, root_inv, keep_bits) if i + 1 < blocks.size
          end
          r = fp_rem(acc, m_root, root_inv, keep_bits)
        end

        out = []
        eval_descend(r, tree, keep_bits, out)
        emax = out.map {|_, e| e }.max
        [out.map {|v, e| e == emax ? v : v >> (emax - e) }, emax]
      end

      # Guard bits on top of the target precision.
      # Measured loss with guard = 0 is 2.9 - 3.3 * m * n1.bit_length bits over
      # prec = 300 .. 10000, identical for both eval modes and for near-node x:
      # the value dynamic range across batches dominates every other rounding.
      # 4 * m * n1.bit_length keeps a ~20% multiplicative margin over that.
      def self.guard_bits(m, n1)
        4 * m * n1.bit_length + 256
      end

      # Same contract as Gamma.gamma_lagrange.
      # Interpolation nodes are A .. A + n1 - 1 with A = b - l and n1 = m**2
      # (m odd so that the barycentric reconstruction keeps positive sign);
      # slightly wider than the symmetric b-l .. b+l, which only adds accuracy.
      def self.gamma_lagrange(x, prec) # :nodoc:
        shift = x < 2 * prec ? 2 * prec - x.floor : 0
        x += shift
        x = BigDecimal(x) - 1
        b = x.round
        l = Gamma.gamma_lagrange_l(b, prec)

        m = Integer.sqrt(2 * l) + 1
        m += 1 if m.even?
        n1 = m * m
        a0 = b - l

        keep = Gamma.drop_cap_bits(prec) + guard_bits(m, n1)
        s2 = 1 << keep

        # Fixed-point mantissas (keep fractional bits) of x - a0 and x
        fd = [x.n_significant_digits - x.exponent, 0].max
        p10 = 10**fd
        xa = ((x - a0)._decimal_shift(fd).to_i << keep) / p10

        # Barycentric pair tree over node indices j = 0 .. m-1 (j = 0 carries the
        # leading term of the series). The leaf factors decompose as
        #   den_j = L_j * B_j * I_j,   num_j = -b * L_(j-1) * G_j
        # where only L_j = (x - a0 - j) - z holds full-precision coefficients;
        # B_j = z + j, I_j = a0 + j + z, G_j = n1 - j - z are small. The series
        # numerator then becomes
        #   F01 = sum_j (Omega / L_j) * w_j,  Omega = prod L_i,
        # with w_j collecting only small-coefficient factors. Each node keeps
        # [Omega, Phi, BI, GX] (BI = prod B_i * I_i, GX = (-b)**size * prod G_(i+1),
        # both exact Integer polynomials) and merges as
        #   Omega_P = Omega_A * Omega_C
        #   Phi_P   = (Phi_A * Omega_C) * BI_C + (Omega_A * Phi_C) * GX_A
        # so the only wide-by-wide multiplications are with Omega (degree d),
        # cheaper than merging [sum, mult, den] triples of degree-3d polynomials.
        nodes = (1..m - 1).map do |i|
          [
            fp_normalize([xa - i * s2, -s2], -keep, keep),
            [[1], 0],
            [i * (a0 + i), a0 + 2 * i, 1],
            [-b * (n1 - i - 1), b]
          ]
        end
        while nodes.size > 1
          nodes = nodes.each_slice(2).map do |na, nc|
            next na unless nc
            [
              fp_mult(na[0], nc[0], keep),
              fp_add(
                fp_mult_intpoly(fp_mult(na[1], nc[0], keep), nc[2], keep),
                fp_mult_intpoly(fp_mult(na[0], nc[1], keep), na[3], keep),
                keep
              ),
              convolve(na[2], nc[2]),
              convolve(na[3], nc[3])
            ]
          end
        end
        sub = nodes.first
        f2 = fp_mult_intpoly(sub[0], sub[2], keep)
        # Attach the j = 0 term (Phi = 1, GX = -b * (n1 - 1 - z)):
        # its Omega_C * BI_C part is exactly F2.
        l0 = fp_normalize([xa, -s2], -keep, keep)
        f01 = fp_add(f2, fp_mult_intpoly(fp_mult(l0, sub[1], keep), [-b * (n1 - 1), b], keep), keep)
        fast = eval_mode == :fast || (eval_mode == :auto && m > FAST_EVAL_MIN_BATCHES)
        if fast
          tree = subproduct_tree(0, m)
          v01s, e01 = fp_eval_points(f01, m, m, keep, tree)
          v2s, e2 = fp_eval_points(f2, m, m, keep, tree)
        else
          v01s = Array.new(m) {|k| fp_eval_int(f01, k * m) }
          v2s = Array.new(m) {|k| fp_eval_int(f2, k * m) }
          e01 = f01[1]
          e2 = f2[1]
        end

        sum = BigDecimal(0)
        prod = BigDecimal(1)
        c_k = BigDecimal(1)
        m.times do |k|
          z = k * m
          v01 = v01s[k]
          v2 = v2s[k]
          xaz = x - (a0 + z)

          term = c_k.mult(BigDecimal(v01).mult(1, prec), prec).div(BigDecimal(v2).mult(1, prec), prec).div(xaz, prec)
          sum = sum.add(term, prec)

          # E(z) = prod of (x - a0 - z - j) over the batch, derived from the same
          # computed F2 value: E = F2 * (x - a0 - z) / (B * I) with
          # B * I = prod of (z + j) * (a0 + z + j) for j = 1 .. m-1.
          bik = 1
          (1..m - 1).each {|j| bik *= (z + j) * (a0 + z + j) }
          ek = BigDecimal(v2).mult(1, prec).mult(xaz, prec).div(bik, prec)
          prod = prod.mult(ek, prec)

          if k < m - 1
            rnum = 1
            rden = 1
            (1..m).each do |j2|
              rnum *= n1 - z - j2
              rden *= (z + j2) * (a0 + z + j2)
            end
            c_k = c_k.mult(rnum * (-b)**m, prec).div(rden, prec)
          end
        end
        sum = sum.mult(BigDecimal(2).power(e01 - e2, prec), prec) unless e01 == e2
        prod = prod.mult(BigDecimal(2).power(m * e2, prec), prec) unless e2.zero?

        # Shift product: batches of (x - i) for i = 0 ... shift, remainder handled directly
        if shift > 0
          xi = (x._decimal_shift(fd).to_i << keep) / p10
          leaves = (0...m).map {|j| fp_normalize([xi - j * s2, -s2], -keep, keep) }
          while leaves.size > 1
            leaves = leaves.each_slice(2).map {|p, q| q ? fp_mult(p, q, keep) : p }
          end
          esp = leaves.first
          full = shift / m
          if full > 0
            if fast
              evs, ev = fp_eval_points(esp, m, full, keep)
            else
              evs = Array.new(full) {|k| fp_eval_int(esp, k * m) }
              ev = esp[1]
            end
            full.times do |k|
              prod = prod.mult(BigDecimal(evs[k]).mult(1, prec), prec)
            end
            prod = prod.mult(BigDecimal(2).power(full * ev, prec), prec) unless ev.zero?
          end
          (full * m...shift).each {|i| prod = prod.mult(x - i, prec) }
        end

        base = BigDecimal(b).power(x - a0, prec).div(prod.mult(sum, prec), prec)
        [base, a0, n1 - 1, 0]
      end

      # gamma via the multipoint Lagrange evaluation, for testing.
      # Only supports non-integer x >= 0.5 on the Lagrange path; other inputs
      # are delegated to the regular implementation.
      def self.gamma(x, prec)
        prec = BigDecimal::Internal.coerce_validate_prec(prec, :gamma)
        x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :gamma)
        return Gamma.gamma(x, prec) if x < 0.5 || x.frac.zero?

        prec2 = prec + BigDecimal::Internal::EXTRA_PREC
        base, large_factorial_arg, small_factorial_arg, exp2 = gamma_lagrange(x, prec2)
        ans = base.mult(Gamma.integer_factorial(small_factorial_arg, prec2), prec2)
        ans = ans.mult(BigDecimal(2).power(exp2, prec2), prec2) unless exp2.zero?
        ans.mult(Gamma.integer_factorial(large_factorial_arg, prec2), prec)
      end
    end
  end
end
