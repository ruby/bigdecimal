# frozen_string_literal: true

module BigMath
  # Bit-burst implementation of BigMath.erf and BigMath.erfc.
  #
  # Both functions share the same incremental update: given erf(x0+...+xk) (or erfc),
  # extend to erf(x0+...+xk+x_{k+1}) by adding (or, for erfc, subtracting) the Taylor
  # expansion of the difference function
  #   g(t) := (erf(t + a) - erf(a)) * exp(a**2) * sqrt(pi) / 2     with a = x0+...+xk
  # which satisfies the homogeneous ODE g''(t) + 2*(t+a)*g'(t) = 0.
  # Each step uses binary splitting on the 3-term recurrence of g's Taylor coefficients;
  # split widths x1, x2, ... double in digits, giving quasi-linear total cost.
  #
  # Only the bit-burst seed differs between the two:
  #   erf  : seed = erf(x0) via Taylor expansion at 0
  #   erfc : seed = erfc(x0) via asymptotic expansion (requires x0 large enough;
  #          returns nil if asymptotic cannot reach the requested precision, in which
  #          case erfc(x) is recovered from 1 - erf(x) with extra digits to absorb
  #          cancellation)
  #
  # Edge cases (after symmetry erf(-x) = -erf(x)):
  #   x == 0  : erf = 0
  #   x > 5e9 : erf = 1, erfc underflows
  #   x < 0.5 (erfc only) : compute via 1 - erf to avoid unnecessary work
  module Erf # :nodoc:

    # Calculates erf with given precision.
    def self.erf(x, prec) # :nodoc:
      prec = BigDecimal::Internal.coerce_validate_prec(prec, :erf)
      x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :erf)
      return BigDecimal::Internal.nan_computation_result if x.nan?
      return BigDecimal(x.infinite?) if x.infinite?
      return BigDecimal(0) if x == 0
      return -erf(-x, prec) if x < 0
      return BigDecimal(1) if x > 5000000000 # erf(5000000000) > 1 - 1e-10000000000000000000
      if x > 8
        xf = x.to_f
        log10_erfc = -xf ** 2 / Math.log(10) - Math.log10(xf * Math::PI ** 0.5)
        erfc_prec = [prec + log10_erfc.ceil, 1].max
        erfc = erfc_bit_burst(x, erfc_prec + BigDecimal::Internal::EXTRA_PREC)
        return BigDecimal(1).sub(erfc, prec) if erfc
      end

      erf_bit_burst(x, prec + BigDecimal::Internal::EXTRA_PREC).mult(1, prec)
    end

    # Calculates erfc with given precision.
    def self.erfc(x, prec) # :nodoc:
      prec = BigDecimal::Internal.coerce_validate_prec(prec, :erfc)
      x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :erfc)
      return BigDecimal::Internal.nan_computation_result if x.nan?
      return BigDecimal(1 - x.infinite?) if x.infinite?
      return BigDecimal(1).sub(erf(x, prec + BigDecimal::Internal::EXTRA_PREC), prec) if x < 0.5
      return BigDecimal::Internal.underflow_computation_result if x > 5000000000 # erfc(5000000000) < 1e-10000000000000000000 (underflow)

      if x > 8
        y = erfc_bit_burst(x, prec + BigDecimal::Internal::EXTRA_PREC)
        return y.mult(1, prec) if y
      end

      # erfc(x) = 1 - erf(x) < exp(-x**2)/x/sqrt(pi)
      # Precision of erf(x) needs about log10(exp(-x**2)/x/sqrt(pi)) extra digits
      log10 = 2.302585092994046
      xf = x.to_f
      high_prec = prec + BigDecimal::Internal::EXTRA_PREC + ((xf**2 + Math.log(xf) + Math.log(Math::PI)/2) / log10).ceil
      BigDecimal(1).sub(erf_bit_burst(x, high_prec), prec)
    end

    # Matrix multiplication. m1 and m2 are size*size length array that represents size*size matrix
    def self.matrix_mult(m1, m2, size, prec) # :nodoc:
      (size * size).times.map do |i|
        size.times.map do |k|
          m1[i / size * size + k].mult(m2[size * k + i % size], prec)
        end.reduce {|a, b| a.add(b, prec) }
      end
    end

    # Returns (erf(x + a) - erf(a)) * exp(a**2) * sqrt(pi) / 2 calculated with binary splitting method.
    def self.erf_binary_splitting_diff(x, a, prec) # :nodoc:
      # Let f(x) = (erf(x + a) - erf(a)) * exp(a**2) * sqrt(pi) / 2
      # f(x) satisfies the following differential equation:
      #   2*(x+a)*f'(x) + f''(x) = 0
      # We can derive the following recurrence for the Taylor coefficients of f:
      # f(x) = x * (c0 + c1*x + c2*x**2 + c3*x**3 + ...)
      # c(0) = 1
      # c(1) = -a
      # c(i) = -2 * (a * c(i - 1) + c(i - 2) * (i - 1) / i) / (i + 1)

      # Estimate required number of terms by calculating c(i) with low precision
      coefs = [BigDecimal(1), BigDecimal(-a)]
      xn = BigDecimal(1)
      low_prec = 10
      x_low = x.mult(1, low_prec)
      threshold = BigDecimal(1)._decimal_shift(-prec)
      steps = (2..).find do |n|
        prevprev, prev = coefs
        xn = xn.mult(x_low, low_prec)
        coefs = prev, (a * prev + prevprev * (n - 1) / n).mult(-2, low_prec).div(n + 1, low_prec)
        coefs[0].mult(xn, low_prec).abs < threshold && coefs[1].mult(xn * x_low, low_prec).abs < threshold
      end

      # Let M(i) be a 2x2 matrix that generates the next coefficients vector (c(i-1), c(i))
      # from the previous two coefficients (c(i-2), c(i-1)).
      # M(i) = | 0,                1          |
      #        | -2*(i-1)/i/(i+1), -2*a/(i+1) |
      #
      # Then, we can calculate (c(steps-1), c(steps)) as M(steps)*M(steps-1)*...*M(2)*Vector(c0, c1).
      #
      # Calculate a matrix that represents the sum of the Taylor series:
      #   SumMatrix = ((((...+I)x*M4+I)*x*M3+I)*M2*x+I)
      # Actual sum can be calculated as:
      #   SumMatrix * Vector(c0, c1) = Vector(c0+c1*x+c2*x**2+c3*x**3+..., _)
      # In this binary splitting method, adjacent two operations are combined into one repeatedly.
      # ((...) * x * A + B) / C is the form of each operation. A and B are 2x2 matrices, C is a scalar.

      zero = BigDecimal(0)
      operations = (2..steps + 2).map do |i|
        d = BigDecimal(i * (i + 1))
        [[zero, d, BigDecimal(-2 * (i - 1)), a * (-2 * i)], [d, zero, zero, d], d]
      end

      while operations.size > 1
        xpow = xpow ? xpow.mult(xpow, prec) : x.mult(1, prec)
        operations = operations.each_slice(2).map do |op1, op2|
          # Combine two operations into one:
          # (((Remaining * x * A2 + B2) / C2) * x * A1 + B1) / C1
          # ((Remaining * (x*x) * (A2*A1) + (x*B2*A1+B1*C2)) / (C1*C2)
          # Therefore, combined operation can be represented as:
          # Anext = A2 * A1
          # Bnext = x * B2 * A1 + B1 * C2
          # Cnext = C1 * C2
          # xnext = x * x
          a1, b1, c1 = op1
          a2, b2, c2 = op2 || [[zero] * 4, [zero] * 4, BigDecimal(1)]
          [
            matrix_mult(a2, a1, 2, prec),
            array_weighted_sum(matrix_mult(b2, a1, 2, prec), xpow, b1, c2, prec),
            c1.mult(c2, prec),
          ]
        end
      end
      _, sum_matrix, denominator = operations.first
      sum = (sum_matrix[0] - a * sum_matrix[1]).div(denominator, prec)
      x.mult(sum, prec)
    end

    # Calculates erfc(x) using bit-burst algorithm.
    # Returns nil if the asymptotic expansion does not reach the requested precision.
    def self.erfc_bit_burst(x, prec) # :nodoc:
      # By bounding the relative error via |d(erfc)/erfc| <= 2*x*|dx| (erfc(x) decays as exp(-x**2)/x),
      # truncate x to the minimum digits sufficient for prec-digit accuracy of the result.
      x = x.mult(1, prec + Math.log10(2 * x.to_f**2).ceil)
      erf_erfc_bit_burst(x, prec, start_digits: 40, mode: :erfc)
    end

    # Calculates erf(x) using bit-burst algorithm.
    def self.erf_bit_burst(x, prec) # :nodoc:
      # By bounding the error via erf'(x) = (2/sqrt(pi)) * exp(-x**2),
      # truncate x to the minimum digits sufficient for prec-digit accuracy of the result.
      x = x.mult(1, [(prec - x.floor**2 / Math.log(10) + Math.log10(x.ceil)).ceil, 10].max)
      erf_erfc_bit_burst(x, prec, start_digits: 8, mode: :erf)
    end

    # Calculates erf or erfc using bit-burst algorithm.
    # Returns nil if erfc mode cannot reach the requested precision.
    def self.erf_erfc_bit_burst(x, prec, start_digits:, mode:) # :nodoc:
      digits = [-x.exponent * 2, start_digits].max
      partial = x.truncate(digits)
      case mode
      when :erf
        f = erf_exp2_binary_splitting(partial, prec)
      when :erfc
        f = erfc_exp2_asymptotic_binary_splitting(partial, prec)
        return unless f
      end

      exp_scale = BigMath.exp(-partial * partial, prec)
      f = f.mult(exp_scale, prec)

      calculated_x = partial
      x -= partial

      until x.zero?
        digits *= 2
        partial = x.truncate(digits)
        next if partial.zero?

        diff_prec = [prec - f.exponent + exp_scale.exponent + partial.exponent, 1].max
        diff = erf_binary_splitting_diff(partial, calculated_x, diff_prec)
        case mode
        when :erf
          f = f.add(diff.mult(exp_scale, prec), prec)
        when :erfc
          f = f.sub(diff.mult(exp_scale, prec), prec)
        end

        calculated_x += partial
        x -= partial
        exp_scale = exp_scale.mult(BigMath.exp(partial * (partial - 2 * calculated_x), diff_prec), diff_prec) unless x.zero?
      end
      f.mult(BigDecimal(2).div(BigMath::PI(prec).sqrt(prec), prec), prec)
    end

    # Matrix/Vector weighted sum
    def self.array_weighted_sum(m1, w1, m2, w2, prec) # :nodoc:
      m1.zip(m2).map {|v1, v2| (v1 * w1).add(v2 * w2, prec) }
    end

    # Calculates Taylor expansion of erf(x)*exp(x**2)*sqrt(pi)/2 with binary splitting method.
    def self.erf_exp2_binary_splitting(x, prec) # :nodoc:
      # Let f(x) = erf(x)*exp(x**2)*sqrt(pi)/2
      #            = c0 + c1*x + c2*x**2 + c3*x**3 + c4*x**4 + ...
      # f(x) is designed to make all coefficients positive so that we don't need to consider cancellation error.
      #
      # f(x) satisfies the following differential equation:
      # f'(x) = 1 + 2 * x * f(x)
      # f'(x) = c1 + 2*c2*x + 3*c3*x**2 + 4*c4*x**3 + 5*c5*x**4 + ...
      #         = 1+2*x*(c0 + c1*x + c2*x**2 + c3*x**3 + c4*x**4 + ...)
      # therefore,
      # c0 = 0
      # c1 = 1
      # c2 = 2 * (c0 + c1) / 2
      # c3 = 2 * (c1 + c2) / 3
      # c4 = 2 * (c2 + c3) / 4

      # Find the smallest n where the n-th Taylor term |c_n * x^n| falls below the precision
      # threshold, using a Stirling-based upper bound on |c_n|.
      log10f = Math.log(10)
      cexponent = Math.log10(Math.sqrt(2)) + BigDecimal::Internal.float_log(x.abs) / log10f

      x_to_f = x < 1e-300 ? 1e-300 : x.to_f # x.to_f may underflow when x is very small (e.g. 1e-400)
      steps = (2..).bsearch do |n|
        x_to_f ** 2 < n && n * cexponent + Math.lgamma(n / 2)[0] / log10f + n * Math.log10(2) - Math.lgamma(n - 1)[0] / log10f < -prec + x_to_f**2 / log10f
      end

      denominators = (steps / 2).times.map {|i| 2 * i + 3 }
      x.mult(1 + BigDecimal::Internal.taylor_sum_binary_splitting(2 * x * x, denominators, prec), prec)
    end

    # Calculates asymptotic expansion of erfc(x)*exp(x**2)*sqrt(pi)/2 with binary splitting method
    def self.erfc_exp2_asymptotic_binary_splitting(x, prec) # :nodoc:
      # Let f(x) = erfc(x)*sqrt(pi)*exp(x**2)/2
      # f(x) satisfies the following differential equation:
      # 2*x*f(x) = f'(x) + 1
      # From the above equation, we can derive the following asymptotic expansion:
      # f(x) = (0..kmax).sum { (-1)**k * (2*k)! / 4**k / k! / x**(2*k) } / x

      # This asymptotic expansion does not converge.
      # But if there is a k that satisfies (2*k)! / 4**k / k! / x**(2*k) < 10**(-prec),
      # It is enough to calculate erfc within the given precision.
      # Using Stirling's approximation, we can simplify this condition to:
      # log(2)/2 + k*log(k) - k - 2*k*log(x) < -prec*log(10)
      # and the left side is minimized when k = x**2.
      xf = x.to_f
      kmax = (1..(xf ** 2).floor).bsearch do |k|
        Math.log(2) / 2 + k * Math.log(k) - k - 2 * k * Math.log(xf) < -prec * Math.log(10)
      end
      return unless kmax

      # Convert asymptotic expansion to nested form:
      # 1 + a/x + a*b/x/x + a*b*c/x/x/x + a*b*c/x/x/x*rest
      # = 1 + (a/x) * (1 + (b/x) * (1 + (c/x) * (1 + rest)))
      #
      # And calculate it with binary splitting:
      # (a1/d + b1/d * (a2/d + b2/d * (rest)))
      # = ((a1*d+b1*a2)/(d*d) + b1*b2/(d*denominator) * (rest)))
      denominator = x.mult(x, prec).mult(2, prec)
      fractions = (1..kmax).map do |k|
        [denominator, BigDecimal(1 - 2 * k)]
      end
      while fractions.size > 1
        fractions = fractions.each_slice(2).map do |fraction1, fraction2|
          a1, b1 = fraction1
          a2, b2 = fraction2 || [BigDecimal(0), denominator]
          [
            a1.mult(denominator, prec).add(b1.mult(a2, prec), prec),
            b1.mult(b2, prec),
          ]
        end
        denominator = denominator.mult(denominator, prec)
      end
      # Plug rest = 1 into the merged form: the innermost "(1 + rest)" of the nested expansion
      # evaluates to 1 at truncation (rest = 0).
      sum = fractions[0][0].add(fractions[0][1], prec).div(denominator, prec)
      sum.div(x, prec) / 2
    end
  end

  private_constant :Erf
end
