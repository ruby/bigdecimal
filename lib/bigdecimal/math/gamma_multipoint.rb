# frozen_string_literal: true

# Experimental sub-quadratic evaluation of the Lagrange interpolation used by
# BigMath.gamma, targeting full-digit x.
#
# The BSGS branch in gamma.rb costs O(PREC^2 * polylog): every interpolation
# node needs a scalar multiplication against a full-precision power of x.
# This file evaluates the same barycentric sum in O(PREC^1.5 * log PREC) with
# sqrt-size batches in the value domain (Bostan-Gaudry-Schost style):
#   - The per-node transition is the 2x2 matrix [[den_t, 0], [num_t, num_t]].
#     Its batch product P_s(z) = prod_{t=z+1..z+s} A(t) is represented by the
#     values of its entries at z = u * s instead of polynomial coefficients.
#   - Doubling P_2s(z) = P_s(z) * P_s(z + s) extends the value tables by
#     "shift of evaluation values" (one convolution with exact binomial
#     weights and a small-integer reciprocal kernel), then combines pointwise.
#     Costs form a geometric sum over doublings - no product tree, no
#     separate evaluation step.
#   - Values are fixed-point integers with a shared per-table exponent;
#     convolutions run via Kronecker substitution onto Integer multiplication,
#     so quasi-linear (GMP-backed) Integer multiplication is required.
#
# The batch denominator values used in prod are derived from the same computed
# D_k used in sum (E_k = D_k / (B*I) with exact integer B, I), so the near-node
# cancellation between prod and sum stays exact, like the batch_prod reuse in
# the BSGS branch.

require 'bigdecimal/math/gamma'

module BigMath
  module Gamma
    module Multipoint # :nodoc:

      # Dispatch control (used by Gamma.gamma_lagrange). The multipoint path
      # requires GMP-backed Integer multiplication: with Toom-Cook the pipeline
      # is asymptotically worse than BSGS. min_prec is the measured crossover
      # against BSGS (~2500 digits) with margin. enabled = false is the kill switch.
      @enabled = !!defined?(Integer::GMP_VERSION)
      @min_prec = 3000

      class << self
        attr_accessor :enabled, :min_prec
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

      # ---------- fixed-point value tables ----------
      # Represented as [values, exp]: entry i holds values[i] * 2**exp.
      # A single exp per table (fixed-point): small entries keep less relative
      # precision, which the guard budget absorbs (dynamic-range dominated).

      def self.fp_normalize(values, exp, keep_bits)
        max = 0
        values.each {|c| bits = c.abs.bit_length; max = bits if bits > max }
        s = max - keep_bits
        return [values, exp] if s <= 0
        [values.map {|c| c >> s }, exp + s]
      end

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

      # Builds the value tables [D, N, M] of the batch transition product
      #   P_s(z) = prod_{t=z+1..z+s} [[den_t, 0], [num_t, num_t]]
      # at z = u * cap_s (u = 0..3*cap_s). This driver is client-independent:
      # any series of prefix products of num_t/den_t fits, as long as den_t and
      # num_t are polynomials in t. The block yields their fixed-point mantissas
      # [den_t, num_t] (at exponent -keep_bits) for t = 1..4; a cubic den and a
      # quadratic num are the highest degrees these four samples support.
      # cap_s must be a power of two.
      def self.batch_value_tables(cap_s, keep_bits)
        dv = []
        nv = []
        (1..4).each do |t|
          d, n = yield(t)
          dv << d
          nv << n
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

      # Guard bits on top of the target precision.
      # Measured loss with guard = 0 is 1.35 - 1.49 * s * n1.bit_length bits over
      # prec = 300 .. 10000, identical for near-node x. The extrapolation of the
      # value shifts does not amplify errors beyond the table dynamic range (the
      # polynomial itself grows at the same rate outside the sampled window).
      # 2 * s * (bit_length + 4) keeps a ~1.9x margin.
      def self.guard_bits(s, n1)
        2 * s * (n1.bit_length + 4) + 256
      end

      # Same contract as Gamma.gamma_lagrange.
      # Interpolation nodes are A .. A + n1 - 1 with n1 = S * G + 1, S = 2**kappa
      # =~ sqrt(2l): slightly wider than the symmetric b-l .. b+l, which only
      # adds accuracy. S is even, so the barycentric reconstruction sign
      # (-1)**(n1 - 1) is positive.
      def self.gamma_lagrange(x, prec) # :nodoc:
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

        keep = Gamma.drop_cap_bits(prec) + guard_bits(s_cap, n1)
        s2 = 1 << keep
        fd = [x.n_significant_digits - x.exponent, 0].max
        p10 = 10**fd
        xa = ((x - a0)._decimal_shift(fd).to_i << keep) / p10

        dtab, ntab, mtab = batch_value_tables(s_cap, keep) do |t|
          xat = xa - t * s2
          [xat * (t * (a0 + t)), (xat + s2) * (-b * (n1 - t))]
        end
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
      # size from the value table, remainder factors direct.
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
    end
  end
end
