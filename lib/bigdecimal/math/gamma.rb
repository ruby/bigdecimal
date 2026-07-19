# frozen_string_literal: true
require 'bigdecimal/math'

module BigMath

  # Calculates gamma/lgamma
  # Algorithm overview:
  #
  # Lagrange interpolation of f(x) = b**x / x! at integer nodes x_i = b-l, ..., b+l.
  #   BSM(Binary Splitting Method) version for small digit numbers, O(PREC*log(PREC)^3)
  #   BSGS(Baby-Step Giant-Step) version for full digit numbers, O(PREC^2*log(log(PREC)))
  #   Both magnitude of order faster than Spouge's approximation which is O(PREC^2*log(PREC))
  #   (Complexities assume quasi-linear multiplication, counting large-by-small products
  #   as (n/m) * M(m) = n * log(m) bit ops. BigDecimal multiplies the small coefficients
  #   by schoolbook instead: an extra log factor asymptotically, but faster at any feasible PREC.)
  #   Requires fast calculation of factorial(nearly_x_integer).
  #
  # Factorial Doubling for fast calculation of large factorials:
  #   Using Legendre duplication formula, we can calculate factorial(2n) from factorial(n) and factorial(n + 0.5).
  #   Calculating factorial(n + 0.5) is done by an optimized BSM version of Lagrange interpolation in quasi-linear time.
  #   This will drastically reduce the cost of calculating large factorials.
  #   O(PREC*log(PREC)^3*log(factorial_argument))
  #
  # Stirling's approximation with Bernoulli numbers
  #   Only used when x is extremely large.

  module Gamma # :nodoc:

    # Calculates gamma function with given precision.
    def self.gamma(x, prec)
      prec = BigDecimal::Internal.coerce_validate_prec(prec, :gamma)
      x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :gamma)
      prec2 = prec + BigDecimal::Internal::EXTRA_PREC

      if x < 0.5
        raise Math::DomainError, 'Numerical argument is out of domain - gamma' if x.frac.zero?

        # Euler's reflection formula: gamma(z) * gamma(1-z) = pi/sin(pi*z)
        pi = BigMath::PI(prec2)
        sin = sinpix(x, pi, prec2)
        pi.div(gamma(1 - x, prec2).mult(sin, prec2), prec)
      elsif x.frac.zero?
        integer_factorial(x.to_i - 1, prec2).mult(1, prec)
      else
        base, large_factorial_arg, small_factorial_arg = gamma_lagrange(x, prec2)
        base.mult(
          integer_factorial(small_factorial_arg, prec2),
          prec2
        ).mult(
          integer_factorial(large_factorial_arg, prec2),
          prec
        )
      end
    end

    # Calculates log gamma and its sign with given precision.
    def self.lgamma(x, prec) # :nodoc:
      prec = BigDecimal::Internal.coerce_validate_prec(prec, :lgamma)
      x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :lgamma)
      prec2 = prec + BigDecimal::Internal::EXTRA_PREC
      if x < 0.5
        return [BigDecimal::INFINITY, 1] if x.frac.zero?

        loop do
          # Euler's reflection formula: gamma(z) * gamma(1-z) = pi/sin(pi*z)
          pi = BigMath::PI(prec2)
          sin = sinpix(x, pi, prec2)
          log_gamma = BigMath.log(pi, prec2).sub(lgamma(1 - x, prec2).first + BigMath.log(sin.abs, prec2), prec)
          return [log_gamma, sin > 0 ? 1 : -1] if log_gamma != 0 && prec2 + log_gamma.exponent > prec + BigDecimal::Internal::EXTRA_PREC

          # Retry with higher precision if loss of significance is too large
          prec2 = prec2 * 3 / 2
        end
      else
        # if x is close to 1 or 2, increase precision to reduce loss of significance
        diff1_exponent = x < 3 ? (x - 1).exponent : 0
        diff2_exponent = x < 3 ? (x - 2).exponent : 0
        extremely_near_one = diff1_exponent < -prec2
        extremely_near_two = diff2_exponent < -prec2

        if extremely_near_one || extremely_near_two
          # If x is extreamely close to base = 1 or 2, linear interpolation is accurate enough.
          # Taylor expansion at x = base is: (x - base) * digamma(base) + (x - base) ** 2 * trigamma(base) / 2 + ...
          # And we can ignore (x - base) ** 2 and higher order terms.
          base = extremely_near_one ? 1 : 2
          d = BigDecimal(1)._decimal_shift(1 - prec2)
          log_gamma_d, sign = lgamma(base + d, prec2)
          return [log_gamma_d.mult(x - base, prec2).div(d, prec), sign]
        end

        prec2 += [-diff1_exponent, -diff2_exponent, 0].max

        # When x is extremely large, the cost of Bernoulli number generation for Stirling's
        # asymptotic expansion is smaller than the cost of multiple steps of doubling method.
        # The condition is based on heuristic cost estimation and empirical tuning.
        if x > prec2 && x.exponent > Integer.sqrt(prec2) / 6
          [lgamma_stirling(x, prec2).mult(1, prec), 1]
        elsif x.frac.zero?
          [integer_factorial_log(x.to_i - 1, prec2).mult(1, prec), 1]
        else
          base, large_factorial_arg, small_factorial_arg = gamma_lagrange(x, prec2)
          lgamma = BigMath.log(base, prec2).add(
            integer_factorial_log(small_factorial_arg, prec2),
            prec2
          ).add(
            integer_factorial_log(large_factorial_arg, prec2),
            prec
          )
          [lgamma, 1]
        end
      end
    end

    # Calculates prod { x - k } and its coefficients for given ks, xn and prec with baby-step giant-step method.
    # xn is an array of precalculated powers of x: [1, x, x**2, x**3, ...]
    def self.x_minus_k_prod_coef(ks, xn, prec) # :nodoc:
      coef = [1]
      ks.each do |k|
        coef_next = [0] * (coef.size + 1)
        coef.each_with_index do |c, i|
          coef_next[i] -= k * c
          coef_next[i + 1] += c
        end
        coef = coef_next
      end

      prod = coef.each_with_index.map do |c, i|
        xn[i].mult(c, prec)
      end.reduce do |sum, value|
        sum.add(value, prec)
      end
      [prod, coef]
    end

    # Calculate numbers.reduce(:*) in a given precision by Binary Splitting Method.
    def self.bsm_prod(numbers, prec)
      numbers = numbers.map {|i| BigDecimal(i) }
      numbers = numbers.each_slice(2).map {|a, b| b ? a.mult(b, prec) : a } while numbers.size > 1
      return numbers.first || BigDecimal(1)
    end

    # Calculate factorial for integer n
    def self.integer_factorial(n, prec)
      power_part, exp2, exp_sqrtpi = integer_factorial_parameter(n, prec)
      ans = BigDecimal(2).power(exp2, prec)
      power_part.each_with_index do |base, index|
        ans = ans.mult(base.power(1 << index, prec), prec)
      end
      if exp_sqrtpi != 0
        pi = BigMath::PI(prec)
        pipow = pi.power(exp_sqrtpi / 2, prec)
        pipow = pipow.mult(pi.sqrt(prec), prec) if exp_sqrtpi.odd?
        ans = ans.div(pipow, prec)
      end
      ans
    end

    # Calculate log factorial for integer n
    def self.integer_factorial_log(n, prec)
      power_part, exp2, exp_sqrtpi = integer_factorial_parameter(n, prec)
      ans = exp2.zero? ? BigDecimal(0) : BigMath.log(2, prec) * exp2
      power_part.each_with_index do |base, index|
        ans = ans.add(BigMath.log(base, prec) * (1 << index), prec)
      end
      if exp_sqrtpi != 0
        pi = BigMath::PI(prec)
        ans = ans.sub(BigMath.log(pi, prec) * (BigDecimal(exp_sqrtpi) / 2), prec)
      end
      ans
    end

    # Calculates parameters for integer factorial calculation.
    # Returns [base_power_part, exp2, exp_sqrtpi] that can produce factorial(n) as:
    #   factorial(n) = prod { base_power_part[i]**(1 << i) } * 2**exp2 / sqrt(pi)**exp_sqrtpi
    # These parameters are used to avoid overflow when calculating log factorial and lgamma for large n.
    def self.integer_factorial_parameter(n, prec)
      base_power_part, factorial_power_part, exp2, exp_sqrtpi = integer_factorial_recursive(n, prec)
      fact_x = 1
      fact_y = BigDecimal(1)
      # factorial_power_part is non-decreasing (deeper recursion levels have smaller b,
      # and gamma_lagrange_l grows as b shrinks), so fact_y can be extended incrementally.
      factorial_power_part.each_with_index do |factorial_arg, index|
        fact_y = fact_y.mult(bsm_prod(fact_x + 1..factorial_arg, prec), prec)
        fact_x = factorial_arg
        base_power_part[index] = base_power_part[index].mult(fact_y, prec)
      end
      [base_power_part, exp2, exp_sqrtpi]
    end

    # Returns [base_power_part, factorial_power_part, exp2, exp_sqrtpi] that can produce factorial(n) as:
    # factorial(n) = prod { base_power_part[i]**(1 << i) } * prod { factorial(factorial_power_part[i])**(1 << i) } * 2**exp2 / sqrt(pi)**(exp_sqrtpi)
    # If n is large, this method recursively calculates factorial for smaller n by Legendre duplication formula.
    def self.integer_factorial_recursive(n, prec)
      if n < 4 * prec
        return [[bsm_prod(1..n, prec)], [], 0, 0]
      end

      # Use Legendre duplication formula to calculate double factorials:
      #   factorial(n) = factorial(n/2.0) * factorial((n-1)/2.0) * 2**n / sqrt(pi)
      # gamma_lagrange_n_plus_half((n+1)/2, prec) computes the half-integer factorial
      # (whichever of the two factors above is a half-integer).
      base, large_factorial_arg, small_factorial_arg = gamma_lagrange_n_plus_half((n + 1) / 2, prec)

      base = base.mult(bsm_prod(large_factorial_arg + 1..n / 2, prec), prec)
      base_power_part, factorial_power_part, exp2, exp_sqrtpi = integer_factorial_recursive(large_factorial_arg, prec)
      [
        [base] + base_power_part,
        [small_factorial_arg] + factorial_power_part,
        exp2 * 2 + n,
        exp_sqrtpi * 2 + 1
      ]
    end

    # Estimate the required number of interpolation points `l` to achieve `prec` digits.
    #
    # Assuming the nodes stay strictly positive, the function b^x/x! approximates a
    # Gaussian curve e^(-y^2 / 2b) around its peak (x=b).
    # The Taylor coefficient of degree 2l is roughly c_2l = 1 / (l! * (2b)^l).
    # Multiplying this by the distance product of 2l+1 nodes (approx (l/e)^(2l)),
    # the overall truncation error E is bounded by: E ~ (l / 2eb)^l.
    #
    # Setting E <= 10^-prec gives the implicit equation:
    #   l * log10(2 * e * b / l) = prec  =>  l = prec / log10(2 * e * b / l)
    def self.gamma_lagrange_l(b, prec)
      # Initial guess of l. When b >= 2 * prec - 1 (guaranteed by the shift in gamma_lagrange),
      # this is safely larger than the actual l.
      l = prec

      # Solves the implicit equation via fixed-point iteration.
      # Due to the slow growth of the logarithm, 2 iterations are practically sufficient.
      2.times { l = prec / Math.log10(2 * Math::E * b / l) }
      l.ceil + 10 # Adds safety margin
    end

    # Calculate approximate gamma by Lagrange interpolation of f(x) = b**x / x!
    # Nodes are placed at x_i = b-l, b-l+1, ..., b+l.
    # b: x.round, l: number of nodes on one side (total nodes = 2*l+1)
    #
    # Mathematically, we use the barycentric interpolation form:
    # f(x) \approx \omega(x) \sum_{i} \frac{w_i f(x_i)}{x - x_i}
    # Therefore, \Gamma(x+1) = x! = b**x / f(x)
    #
    # Time complexity:
    # - O(PREC*log(PREC)^3) for small-digit x (Binary Splitting)
    # - O(PREC^2) for full-digit x (Baby-step Giant-step)
    #
    # Returns [base, large_factorial_arg, small_factorial_arg] that can produce gamma(x) as:
    #   gamma(x) = base * factorial(large_factorial_arg) * factorial(small_factorial_arg)
    def self.gamma_lagrange(x, prec) # :nodoc:
      # Shift x to establish a safe center (b) for the barycentric interpolation.
      #
      # We must keep all interpolation nodes strictly positive (b - l > 0). Approaching
      # x = 0 breaks the Gaussian approximation used to estimate `l` and provides no
      # useful information for the interpolation.
      #
      # While b =~ 1.36 * prec is the strict theoretical minimum to stay positive, we
      # heuristically use b = 2 * prec. This moves the nodes safely away from x = 0,
      # stabilizes the curve, and empirically yields the optimal total computation cost.
      # (See `gamma_lagrange_l` for the mathematical derivation of the approximation).
      shift = x < 2 * prec ? 2 * prec - x.floor : 0
      x += shift

      x = BigDecimal(x) - 1
      b = x.round
      l = gamma_lagrange_l(b, prec)

      # --- Reference: Naive interpolation logic ---
      # Optimize this calculation for full-digit-x case and small-digit-x case.
      # sum = BigDecimal(0)
      # prod = [*(b - l..b + l), *(0...shift)].map {|i| x - i }.reduce { _1.mult(_2, prec) }
      # c = BigDecimal(1) # represents w_i * f(x_i) (normalized)
      # (b - l..b + l).each do |i|
      #   if i != b - l
      #     c = c.mult(-b * (b + l - i + 1), prec).div((i - b + l) * i, prec)
      #   end
      #   sum = sum.add(c.div(x - i, prec), prec)
      # end
      # --------------------------------------------

      # Choose between BSM and BSGS based on total bit cost:
      #   BSM:  (l * n_sig / prec) full-digit multiplications, each costing prec * log(prec)
      #         bit ops, total l * n_sig * log(prec).
      #   BSGS: l * prec bit ops with batch_size = log2(prec) (see below).
      # Cross-over: n_sig * log(prec) > prec.
      if x.n_significant_digits * prec.bit_length > prec
        # Reduce full-precision multiplications/divisions using a Batched Evaluation
        # inspired by the Baby-Step Giant-Step (BSGS) method.

        # Normal BSGS uses batch_size = sqrt(l), but here the integer coefficients of the
        # expanded prod { x - k } over a batch grow like (b + l)**batch_size, so a smaller
        # batch keeps both the coefficient size and the per-batch evaluation cost low.
        # batch_size = log2(prec) brings the total BSGS bit cost down to O(l * prec * log(log(prec))).
        batch_size = prec.bit_length

        # When expanding prod { x - k }, the coefficient of x**n might be huge.
        # Increase internal calculation precision to avoid catastrophic cancellation.
        internal_xn_prec = prec + (Math.log10(b + l) * batch_size).ceil
        xn = [BigDecimal(1)]
        xn << xn.last.mult(x, internal_xn_prec) while xn.size <= batch_size

        c = BigDecimal(1)
        sum = BigDecimal(0)
        prod = BigDecimal(1)

        ((b - l)..(b + l)).to_a.each_slice(batch_size) do |batch_ks|
          # Calculate prod{ x - k } in this batch
          batch_prod, prod_coef = x_minus_k_prod_coef(batch_ks, xn, internal_xn_prec)

          # Calculate coefficients of batch_prod / (x - k) using Synthetic Division (Ruffini's rule)
          batch_coef = [0] * batch_ks.size
          c_scale = 1r
          batch_ks.each do |k|
            c_scale = c_scale * (-b * (b + l - k + 1)) / ((k - b + l) * k) if k != b - l
            rem = 0
            (batch_ks.size - 1).downto(0) do |i|
              quo = prod_coef[i + 1] + rem
              rem = quo * k
              batch_coef[i] += c_scale * quo
            end
          end

          batch_sum = BigDecimal(0)
          batch_coef.each_with_index do |coef, i|
            batch_sum = batch_sum.add(xn[i].mult(coef.numerator, internal_xn_prec).div(coef.denominator, internal_xn_prec), internal_xn_prec)
          end
          # batch_prod loses relative accuracy when x is extremely close to a node in this
          # batch. This is harmless: the same computed value is divided into sum here and
          # multiplied into prod below, so the error cancels in the final prod * sum.
          sum = sum.add(batch_sum.mult(c, prec).div(batch_prod, prec), prec)
          c = c.mult(c_scale.numerator, prec).div(c_scale.denominator, prec)
          prod = prod.mult(batch_prod, prec)
        end

        # Perform shift.times {|i| prod = prod.mult(x - i, prec) } with batch processing
        shift.times.to_a.each_slice(batch_size) do |batch_ks|
          shift_prod, _prod_coef = x_minus_k_prod_coef(batch_ks, xn, internal_xn_prec)
          prod = prod.mult(shift_prod, prec)
        end
      else
        # Binary Splitting Method (BSM) for short-digit inputs

        prod = bsm_prod((b - l..b + l).map {|i| x - i } + shift.times.map {|i| x - i }, prec)

        # State represents a partial evaluation of the series as: [sum_num, mult_num, den]
        # Conceptually, each state translates to the following mathematical expression:
        #   (sum_num / den) + (mult_num / den) * (rest_of_the_series)
        #
        # The initial state [denominator, numerator, denominator] simply represents:
        #   (denominator / denominator) + (numerator / denominator) * rest
        #   = 1 + (numerator / denominator) * rest
        #
        fractions = (b - l + 1..b + l).map do |i|
          denominator = (x - i).mult((i - b + l) * i, prec)
          numerator = (x - i + 1).mult(-b * (b + l - i + 1), prec)
          [denominator, numerator, denominator]
        end

        while fractions.size > 1
          fractions = fractions.each_slice(2).map do |a, b|
            b ||= [BigDecimal(1), BigDecimal(0), BigDecimal(1)]
            # Merge operation for BSM:
            # a[0]/a[2] + a[1]/a[2] * (b[0]/b[2] + b[1]/b[2] * rest)
            # = (a[0]*b[2] + a[1]*b[0]) / (a[2]*b[2]) + (a[1]*b[1]) / (a[2]*b[2]) * rest
            [a[0].mult(b[2], prec).add(a[1].mult(b[0], prec), prec), a[1].mult(b[1], prec), a[2].mult(b[2], prec)]
          end
        end
        sum = fractions[0][0].add(fractions[0][1], prec).div(fractions[0][2], prec).div(x - b + l, prec)
      end

      # Reconstruct Gamma(x_original) by reversing the scaling and applying shift formula
      base = BigDecimal(b).power(x - (b - l), prec).div(prod.mult(sum, prec), prec)
      large_factorial_arg = b - l
      small_factorial_arg = 2 * l
      [base, large_factorial_arg, small_factorial_arg]
    end

    # Specialized version of gamma_lagrange(n + 0.5, prec) for integer n.
    # n should be large enough that it doesn't need shift operation which is omitted in this method.
    # Computation complexity: O(PREC*log(PREC)^3)
    # Same algorithm and return format as gamma_lagrange, but several times faster.
    # Used for double factorial calculation in integer factorial for large n.
    def self.gamma_lagrange_n_plus_half(n, prec) # :nodoc:
      b = n
      l = gamma_lagrange_l(b, prec)
      prods = (b - l..b + l).map {|i| 2 * n - 2 * i - 1 }
      prods = prods.each_slice(2).map {|a, b| b ? a * b : a } while prods.size != 1
      prod = BigDecimal(prods.first).mult(BigDecimal(0.5).power(2 * l + 1, prec), prec)

      # Exactly the same as gamma_lagrange but with x = n + 0.5 and some simplification.
      # numerator and denominator are doubled to make them integers.
      fractions = (b - l + 1..b + l).map do |i|
        denominator = (2 * n - 1 - 2 * i) * ((i - b + l) * i)
        numerator = (2 * n + 1 - 2 * i) * (-b * (b + l - i + 1))
        [denominator, numerator, denominator]
      end
      while fractions.size > 1
        fractions = fractions.each_slice(2).map do |a, b|
          b ||= [1, 0, 1]
          v0 = a[0] * b[2] + a[1] * b[0]
          v1 = a[1] * b[1]
          v2 = a[2] * b[2]
          # Drop lower bits to avoid the integers growing too large.
          # Only about prec * log2(10) bits are needed. 10 / 3 slightly exceeds log2(10),
          # and 64 extra bits absorb the ~1 bit lost per merge level (tree depth is log2(2 * l)).
          s = v2.bit_length - (prec * 10 + 192) / 3
          if s > 0
            v0 >>= s
            v1 >>= s
            v2 >>= s
          end
          [v0, v1, v2]
        end
      end
      fraction = fractions.first
      sum = BigDecimal((fraction[0] + fraction[1]) * 2).div(fraction[2] * (2 * (n - b + l) - 1), prec)
      base = BigDecimal(b).power(n - b + l, prec).div(BigDecimal(b).sqrt(prec).mult(sum.mult(prod, prec), prec), prec)
      large_factorial_arg = b - l
      small_factorial_arg = 2 * l
      [base, large_factorial_arg, small_factorial_arg]
    end

    # Calculates bernoulli number.
    # bns: calculated bernoulli numbers for memoization
    def self.bernoulli(n, bns, prec) # :nodoc:
      return bns[0] ||= BigDecimal(1) if n == 0
      return bns[1] ||= BigDecimal(-0.5) if n == 1
      return bns[n] ||= BigDecimal(0) if n.odd?
      bns[n] ||= (
        comb = 1
        sum = BigDecimal(0)
        n.times.each do |i|
          sum = sum.add(comb * bernoulli(i, bns, prec), prec)
          comb = comb * (n - i + 1) / (i + 1)
        end
        sum.div(-n - 1, prec)
      )
    end

    # Calculate gamma using Stirling's asymptotic expansion.
    # While the condition of this asymptotic expansion is x > prec * log(10) / 2 / pi,
    # we'll use this method only when x is extremely large to reduce the cost of Bernoulli number generation.
    def self.lgamma_stirling(x, prec) # :nodoc:
      x = BigDecimal(x)
      y = (x * (BigMath.log(x, prec) - 1)).add(BigMath.log(2 * BigMath::PI(prec).div(x, prec), prec) / 2, prec)
      bns = []
      xn = x
      x2 = x.mult(x, prec)
      (1..).each do |k|
        xn = xn.mult(x2, prec) if k != 1
        d = bernoulli(2 * k, bns, prec).div(xn, prec).div(2 * k * (2 * k - 1), prec)
        y = y.add(d, prec)
        break if d.exponent < y.exponent - prec
      end
      y
    end

    # Returns sin(pi * x), for gamma reflection formula calculation
    def self.sinpix(x, pi, prec) # :nodoc:
      x = x % 2
      sign = x > 1 ? -1 : 1
      x %= 1
      x = 1 - x if x > 0.5 # to avoid sin(pi*x) loss of precision for x close to 1
      sign * BigMath.sin(x.mult(pi, prec), prec)
    end
  end

  private_constant :Gamma
end
