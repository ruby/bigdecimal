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

      # Dispatch control (used by Gamma.gamma_lagrange). The multipoint path
      # requires GMP-backed Integer multiplication: with Toom-Cook the pipeline
      # is asymptotically worse than BSGS. min_prec is the measured crossover
      # against BSGS (~2000 digits) with margin. enabled = false is the kill switch.
      @enabled = !!defined?(Integer::GMP_VERSION)
      @min_prec = 3000

      # :coeff  = coefficient domain (barycentric pair tree + multipoint evaluation)
      # :values = value domain (BGS shift of evaluation values; no tree, no eval step)
      # :auto   = :values above its measured crossover against :coeff (~7000 digits)
      ENGINE_VALUES_MIN_PREC = 8000
      @engine = :auto

      class << self
        attr_accessor :eval_mode, :enabled, :min_prec, :engine
      end

      # Same full-digit criterion as the BSM/BSGS branch, applied to the shifted x.
      def self.use?(x, prec)
        return false unless @enabled && prec >= @min_prec
        shift = x < 2 * prec ? 2 * prec - x.floor : 0
        (x + shift - 1).n_significant_digits * prec.bit_length > prec
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

      # ---------- value-domain engine (BGS shift of evaluation values) ----------
      # Instead of polynomial coefficients, the batch transition product
      #   P_s(z) = prod_{t=z+1..z+s} [[den_t, 0], [num_t, num_t]]
      # is represented by the values of its entries at z = u * s (u = 0..3s).
      # Doubling: P_2s(z) = P_s(z) * P_s(z + s) needs P_s at u = 0..12s+3, obtained
      # by shifting the value table (one convolution); then one pointwise 2x2
      # product per point. Total cost is a geometric sum over doublings instead
      # of the log(m) equal-cost levels of the coefficient product tree, and no
      # separate evaluation step is needed.

      # Shared kernel for shifting tables of degree d by integer a (a > d):
      # reciprocals 1/(a - d + t) in fixed point, exact delta_k = prod (a + k - j)
      # and d!.
      def self.shift_kernel(d, a, out_len, keep_bits)
        rexp = keep_bits + 64
        recips = Array.new(out_len + d) {|t| (1 << rexp) / (a - d + t) }
        dfact = (1..d).reduce(1, :*)
        deltas = Array.new(out_len)
        delta = (a - d..a).reduce(1, :*)
        out_len.times do |k|
          deltas[k] = delta
          delta = delta / (a + k - d) * (a + k + 1)
        end
        [recips, rexp, deltas, dfact]
      end

      # Values Q(a), ..., Q(a + out_len - 1) of the polynomial of degree
      # vals.size - 1 given by its values Q(0), ..., Q(d)
      # (shift of evaluation values, Bostan-Gaudry-Schost):
      #   Q(a + k) = (delta_k / d!) * sum_i Q(i) * (-1)**(d-i) * C(d,i) / (a + k - i)
      def self.fp_shift_values(table, kernel, keep_bits)
        vals, exp = table
        d = vals.size - 1
        recips, rexp, deltas, dfact = kernel
        comb = 1
        svals = vals.each_with_index.map do |v, i|
          sv = comb * ((d - i).odd? ? -v : v)
          comb = comb * (d - i) / (i + 1)
          sv
        end
        conv = convolve(svals, recips)
        out = Array.new(deltas.size) {|k| conv[k + d] * deltas[k] / dfact }
        fp_normalize(out, exp - rexp, keep_bits)
      end

      def self.table_concat(t1, t2)
        v1, e1 = t1
        v2, e2 = t2
        if e1 > e2
          [v1 + v2.map {|v| v >> (e1 - e2) }, e1]
        elsif e2 > e1
          [v1.map {|v| v >> (e2 - e1) } + v2, e2]
        else
          [v1 + v2, e1]
        end
      end

      # Builds the value tables [D, N, M] of P_cap_s at z = u * cap_s (u = 0..3*cap_s).
      # cap_s must be a power of two.
      def self.batch_value_tables(xa, s2, a0, b, n1, cap_s, keep_bits)
        dv = []
        nv = []
        (0..3).each do |u|
          t = u + 1
          xat = xa - t * s2
          dv << xat * (t * (a0 + t))
          nv << (xat + s2) * (-b * (n1 - t))
        end
        dtab = fp_normalize(dv, -keep_bits, keep_bits)
        ntab = fp_normalize(nv, -keep_bits, keep_bits)
        mtab = ntab
        s = 1
        while s < cap_s
          kernel = shift_kernel(3 * s, 3 * s + 1, 9 * s + 3, keep_bits)
          dvv, de = table_concat(dtab, fp_shift_values(dtab, kernel, keep_bits))
          nvv, ne = table_concat(ntab, fp_shift_values(ntab, kernel, keep_bits))
          mvv, me = table_concat(mtab, fp_shift_values(mtab, kernel, keep_bits))
          # P_2s(u * 2s) = P_s((2u) * s) * P_s((2u + 1) * s), entrywise:
          #   D' = Dl * Dr,  N' = Nl * Dr + Ml * Nr,  M' = Ml * Mr
          e1 = ne + de
          e2 = me + ne
          sh = e1 - e2
          l2 = 6 * s
          nd = Array.new(l2 + 1)
          nn = Array.new(l2 + 1)
          nm = Array.new(l2 + 1)
          (0..l2).each do |j|
            dr = dvv[2 * j + 1]
            nr = nvv[2 * j + 1]
            t1v = nvv[2 * j] * dr
            t2v = mvv[2 * j] * nr
            nd[j] = dvv[2 * j] * dr
            nn[j] = sh >= 0 ? t1v + (t2v >> sh) : (t1v >> -sh) + t2v
            nm[j] = mvv[2 * j] * mvv[2 * j + 1]
          end
          dtab = fp_normalize(nd, 2 * de, keep_bits)
          ntab = fp_normalize(nn, sh >= 0 ? e1 : e2, keep_bits)
          mtab = fp_normalize(nm, 2 * me, keep_bits)
          s *= 2
        end
        [dtab, ntab, mtab]
      end

      # Guard bits for the value-domain engine.
      # Measured loss with guard = 0 is 1.35 - 1.49 * s * n1.bit_length bits over
      # prec = 300 .. 10000, identical for near-node x. The feared extrapolation
      # amplification of the value shifts does not appear beyond the table
      # dynamic range (the polynomial itself grows at the same rate outside the
      # sampled window). 2 * s * (bit_length + 4) keeps a ~1.9x margin.
      def self.guard_bits_values(s, n1)
        2 * s * (n1.bit_length + 4) + 256
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
        if engine == :values || (engine == :auto && prec >= ENGINE_VALUES_MIN_PREC)
          return gamma_lagrange_values(x, prec)
        end

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

        prod = prod.mult(shift_prod_factor(x, fd, p10, shift, keep, prec), prec) if shift > 0

        base = BigDecimal(b).power(x - a0, prec).div(prod.mult(sum, prec), prec)
        [base, a0, n1 - 1, 0]
      end

      # Value table of the shift-product batches Q_s(z) = prod_{j=0..s-1} (x - z - j)
      # at z = u * s (u = 0..s), by the same doubling as batch_value_tables but
      # with a single entry of degree s.
      def self.shift_value_table(xi, s2, cap_s, keep_bits)
        tab = fp_normalize([xi, xi - s2], -keep_bits, keep_bits)
        s = 1
        while s < cap_s
          kernel = shift_kernel(s, s + 1, 3 * s + 1, keep_bits)
          vv, e = table_concat(tab, fp_shift_values(tab, kernel, keep_bits))
          nv = Array.new(2 * s + 1) {|j| vv[2 * j] * vv[2 * j + 1] }
          tab = fp_normalize(nv, 2 * e, keep_bits)
          s *= 2
        end
        tab
      end

      # Product of (x - i) for i = 0 ... shift - 1: full batches of power-of-two
      # size (chosen here, independent of the caller's batch size) from the
      # value table, remainder factors direct.
      def self.shift_prod_factor(x, fd, p10, shift, keep, prec)
        prod = BigDecimal(1)
        full = 0
        mbatch = 1
        if shift >= 4
          mbatch = 1 << [(0.5 * Math.log2(shift)).round, 1].max
          full = shift / mbatch
        end
        if full > 0
          s2 = 1 << keep
          xi = (x._decimal_shift(fd).to_i << keep) / p10
          tab = shift_value_table(xi, s2, mbatch, keep)
          if full > mbatch + 1
            kernel = shift_kernel(mbatch, mbatch + 1, full - mbatch - 1, keep)
            tab = table_concat(tab, fp_shift_values(tab, kernel, keep))
          end
          vals, e = tab
          full.times do |k|
            prod = prod.mult(BigDecimal(vals[k]).mult(1, prec), prec)
          end
          prod = prod.mult(BigDecimal(2).power(full * e, prec), prec) unless e.zero?
        end
        (full * mbatch...shift).each {|i| prod = prod.mult(x - i, prec) }
        prod
      end

      # Same contract as gamma_lagrange, value-domain engine (engine = :values).
      # Nodes are A .. A + n1 - 1 with n1 = S * G + 1, S = 2**kappa =~ sqrt(2l).
      # S is even, so the barycentric reconstruction sign (-1)**(n1 - 1) is
      # positive without any parity constraint on the node count.
      def self.gamma_lagrange_values(x, prec) # :nodoc:
        shift = x < 2 * prec ? 2 * prec - x.floor : 0
        x += shift
        x = BigDecimal(x) - 1
        b = x.round
        l = Gamma.gamma_lagrange_l(b, prec)

        kappa = (0.5 * Math.log2(2 * l)).round
        kappa = 1 if kappa < 1
        s_cap = 1 << kappa
        g = (2 * l + s_cap - 1) / s_cap
        n1 = s_cap * g + 1
        a0 = b - l

        keep = Gamma.drop_cap_bits(prec) + guard_bits_values(s_cap, n1)
        s2 = 1 << keep
        fd = [x.n_significant_digits - x.exponent, 0].max
        p10 = 10**fd
        xa = ((x - a0)._decimal_shift(fd).to_i << keep) / p10

        dtab, ntab, mtab = batch_value_tables(xa, s2, a0, b, n1, s_cap, keep)
        dvals, ed = dtab
        nvals, en = ntab
        mvals, em = mtab

        pw_nd = BigDecimal(2).power(en - ed, prec)
        pw_md = BigDecimal(2).power(em - ed, prec)
        sum_series = BigDecimal(1)
        prod = x - a0
        c_k = BigDecimal(1)
        g.times do |k|
          dk = BigDecimal(dvals[k]).mult(1, prec)
          nk = BigDecimal(nvals[k]).mult(1, prec)
          sum_series = sum_series.add(c_k.mult(nk, prec).div(dk, prec).mult(pw_nd, prec), prec)

          # Same-value invariant: the batch factor of prod is derived from the
          # same computed D_k used in the sum denominator, so near-node errors
          # cancel exactly in prod * sum. BI is the exact small-integer part.
          bik = 1
          t0 = k * s_cap
          (1..s_cap).each {|j| bik *= (t0 + j) * (a0 + t0 + j) }
          prod = prod.mult(dk, prec).div(bik, prec)

          if k < g - 1
            c_k = c_k.mult(BigDecimal(mvals[k]).mult(1, prec), prec).div(dk, prec).mult(pw_md, prec)
          end
        end
        prod = prod.mult(BigDecimal(2).power(g * ed, prec), prec) unless ed.zero?
        sum = sum_series.div(x - a0, prec)

        prod = prod.mult(shift_prod_factor(x, fd, p10, shift, keep, prec), prec) if shift > 0

        base = BigDecimal(b).power(x - a0, prec).div(prod.mult(sum, prec), prec)
        [base, a0, n1 - 1, 0]
      end

    end
  end
end
