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

      # ---------- Kronecker substitution convolution on Integer ----------

      def self.pack(coeffs, slot_hex)
        coeffs.reverse_each.map {|c| c.to_s(16).rjust(slot_hex, '0') }.join.to_i(16)
      end

      def self.pack_signed(coeffs, slot_hex)
        v = pack(coeffs.map {|c| c > 0 ? c : 0 }, slot_hex)
        v -= pack(coeffs.map {|c| c < 0 ? -c : 0 }, slot_hex) if coeffs.any? {|c| c < 0 }
        v
      end

      def self.unpack_signed(n, slot_hex, size)
        half = 1 << (slot_hex * 4 - 1)
        bias = (('8' + '0' * (slot_hex - 1)) * size).to_i(16)
        s = (n + bias).to_s(16).rjust(slot_hex * size, '0')
        (0...size).map {|i| s[(size - 1 - i) * slot_hex, slot_hex].to_i(16) - half }
      end

      # Convolution of signed Integer coefficient arrays.
      def self.convolve(a, b)
        out_size = a.size + b.size - 1
        if a.size < 16 || b.size < 16
          out = Array.new(out_size, 0)
          a.each_with_index {|c, i| b.each_with_index {|d, j| out[i + j] += c * d } }
          return out
        end
        max_bits = 1
        a.each {|c| bits = c.abs.bit_length; max_bits = bits if bits > max_bits }
        b.each {|c| bits = c.abs.bit_length; max_bits = bits if bits > max_bits }
        w = 2 * max_bits + out_size.bit_length + 2
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

      # Merge of [sum_num, mult_num, den] triples, same as the BSM merge in
      # gamma.rb but over polynomials.
      def self.triple_merge(a, c, keep_bits)
        [
          fp_add(fp_mult(a[0], c[2], keep_bits), fp_mult(a[1], c[0], keep_bits), keep_bits),
          fp_mult(a[1], c[1], keep_bits),
          fp_mult(a[2], c[2], keep_bits)
        ]
      end

      # Exact Horner evaluation at an integer point. Returns the Integer mantissa;
      # the value is mantissa * 2**poly_exp.
      def self.fp_eval_int(poly, z)
        acc = 0
        poly[0].reverse_each {|c| acc = acc * z + c }
        acc
      end

      # Guard bits on top of the target precision, absorbing:
      # - coefficient spread and value dynamic range across batches (~m * log2(n1))
      # - rounding of ~log2(m) tree levels and of the evaluation
      # Deliberately generous; to be tightened after error measurements.
      def self.guard_bits(m, n1)
        4 * m * (n1.bit_length + 4) + 256
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

        # Triple tree over leaves t = z + j (j = 1 .. m-1), as polynomials in z:
        #   den_t = (x - a0 - t) * (t * (a0 + t))
        #   num_t = (x - a0 - t + 1) * (-b * (n1 - t))
        identity = [[[1], 0], [[0], 0], [[1], 0]]
        fractions = (1..m - 1).map do |j|
          xaj = xa - j * s2
          den = fp_normalize(
            [xaj * (j * (a0 + j)), xaj * (a0 + 2 * j) - s2 * (j * (a0 + j)), xaj - s2 * (a0 + 2 * j), -s2],
            -keep, keep
          )
          xaj1 = xaj + s2
          num = fp_normalize(
            [-b * xaj1 * (n1 - j), b * (xaj1 + s2 * (n1 - j)), -b * s2],
            -keep, keep
          )
          [den, num, den]
        end
        while fractions.size > 1
          fractions = fractions.each_slice(2).map do |p, q|
            q ||= identity
            triple_merge(p, q, keep)
          end
        end
        f0, f1, f2 = fractions.first
        f01 = fp_add(f0, f1, keep)
        e01 = f01[1]
        e2 = f2[1]

        sum = BigDecimal(0)
        prod = BigDecimal(1)
        c_k = BigDecimal(1)
        m.times do |k|
          z = k * m
          v01 = fp_eval_int(f01, z)
          v2 = fp_eval_int(f2, z)
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
          full.times do |k|
            prod = prod.mult(BigDecimal(fp_eval_int(esp, k * m)).mult(1, prec), prec)
          end
          prod = prod.mult(BigDecimal(2).power(full * esp[1], prec), prec) if full > 0 && !esp[1].zero?
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
