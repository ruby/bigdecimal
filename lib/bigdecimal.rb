if RUBY_ENGINE == 'jruby'
  JRuby::Util.load_ext("org.jruby.ext.bigdecimal.BigDecimalLibrary")
else
  require 'bigdecimal.so'
end

class BigDecimal

  #  call-seq:
  #    self ** other -> bigdecimal
  #
  #  Returns the \BigDecimal value of +self+ raised to power +other+:
  #
  #    b = BigDecimal('3.14')
  #    b ** 2              # => 0.98596e1
  #    b ** 2.0            # => 0.98596e1
  #    b ** Rational(2, 1) # => 0.98596e1
  #
  #  Related: BigDecimal#power.
  #
  def **(y)
    case y
    when BigDecimal, Integer, Float, Rational
      power(y)
    when nil
      raise TypeError, 'wrong argument type NilClass'
    else
      x, y = y.coerce(self)
      x**y
    end
  end

  # call-seq:
  #   power(n)
  #   power(n, prec)
  #
  # Returns the value raised to the power of n.
  #
  # Also available as the operator **.
  #
  def power(y, prec = nil)
    BigMath._validate_prec(prec, :power) if prec
    x = self
    y = BigMath._coerce_to_bigdecimal(y, prec || n_significant_digits, :power)

    return BigMath._nan_computation_result if x.nan? || y.nan?
    return BigDecimal(1) if y.zero?

    if y.infinite?
      if x < 0
        return BigDecimal(0) if x < -1 && y.negative?
        return BigDecimal(0) if x > -1 && y.positive?
        raise Math::DomainError, 'Result undefined for negative base raised to infinite power'
      elsif x < 1
        return y.positive? ? BigDecimal(0) : BigMath._infinity_computation_result
      elsif x == 1
        return BigDecimal(1)
      else
        return y.positive? ? BigMath._infinity_computation_result : BigDecimal(0)
      end
    end

    if x.infinite? && y < 0
      # Computation result will be +0 or -0. Avoid overflow.
      neg = x < 0 && y.frac.zero? && y % 2 == 1
      return neg ? -BigDecimal(0) : BigDecimal(0)
    end

    if x.zero?
      return BigDecimal(1) if y.zero?
      return BigDecimal(0) if y > 0
      if y.frac.zero? && y % 2 == 1 && x.sign == -1
        return -BigMath._infinity_computation_result
      else
        return BigMath._infinity_computation_result
      end
    elsif x < 0
      if y.frac.zero?
        if y % 2 == 0
          return (-x).power(y, prec)
        else
          return -(-x).power(y, prec)
        end
      else
        raise Math::DomainError, 'Computation results in complex number'
      end
    elsif x == 1
      return BigDecimal(1)
    end

    prec ||= BigDecimal.limit.nonzero?
    frac_part = y.frac

    if frac_part.zero? && !prec
      # Infinite precision calculation for `x ** int` and `x.power(int)`
      int_part = y.fix.to_i
      int_part = -int_part if (neg = int_part < 0)
      ans = BigDecimal(1)
      n = 1
      xn = x
      while true
        ans *= xn if int_part.allbits?(n)
        n <<= 1
        break if n > int_part
        xn *= xn
        # Detect overflow/underflow before consuming infinite memory
        if (xn.exponent.abs - 1) * int_part / n >= 0x7FFFFFFFFFFFFFFF
          return ((xn.exponent > 0) ^ neg ? BigMath._infinity_computation_result : BigDecimal(0)) * (int_part.even? || x > 0 ? 1 : -1)
        end
      end
      return neg ? BigDecimal(1) / ans : ans
    end

    prec ||= [x.n_significant_digits, y.n_significant_digits, BigDecimal.double_fig].max + BigDecimal.double_fig

    if y < 0
      inv = x.power(-y, prec)
      return BigDecimal(0) if inv.infinite?
      return BigMath._infinity_computation_result if inv.zero?
      return BigDecimal(1).div(inv, prec)
    end

    int_part = y.fix.to_i
    prec2 = prec + BigDecimal.double_fig
    pow_prec = prec2 + (int_part > 0 ? y.exponent : 0)
    ans = BigDecimal(1)
    n = 1
    xn = x
    while true
      ans = ans.mult(xn, pow_prec) if int_part.allbits?(n)
      n <<= 1
      break if n > int_part
      xn = xn.mult(xn, pow_prec)
    end
    unless frac_part.zero?
      ans = ans.mult(BigMath.exp(BigMath.log(x, prec2).mult(frac_part, prec2), prec2), prec2)
    end
    ans.mult(1, prec)
  end
end

# Core BigMath methods for BigDecimal (log, exp) are defined here.
# Other methods (sin, cos, atan) are defined in 'bigdecimal/math.rb'.
module BigMath

  # Coerce x to BigDecimal with the specified precision.
  # TODO: some methods (example: BigMath.exp) require more precision than specified to coerce.
  def self._coerce_to_bigdecimal(x, prec, method_name, complex_domain_error = false) # :nodoc:
    case x
    when BigDecimal
      return x
    when Integer, Float
      return BigDecimal(x)
    when Rational
      return BigDecimal(x, [prec, 2 * BigDecimal.double_fig].max)
    when Complex
      if complex_domain_error
        raise Math::DomainError, "Complex argument for BigMath.#{method_name}"
      end
    end
    raise ArgumentError, "#{x.inspect} can't be coerced into BigDecimal"
  end

  def self._validate_prec(prec, method_name) # :nodoc:
    raise ArgumentError, 'precision must be an Integer' unless Integer === prec
    raise ArgumentError, "Zero or negative precision for #{method_name}" if prec <= 0
  end

  def self._infinity_computation_result # :nodoc:
    if BigDecimal.mode(BigDecimal::EXCEPTION_ALL).anybits?(BigDecimal::EXCEPTION_INFINITY)
      raise FloatDomainError, "Computation results in 'Infinity'"
    end
    BigDecimal::INFINITY
  end

  def self._nan_computation_result # :nodoc:
    if BigDecimal.mode(BigDecimal::EXCEPTION_ALL).anybits?(BigDecimal::EXCEPTION_NaN)
      raise FloatDomainError, "Computation results to 'NaN'"
    end
    BigDecimal::NAN
  end

  private_class_method def self._log_taylor(x, prec) # :nodoc:
    # Taylor series for log(x) around 1
    # log(x) = -log((1 + X) / (1 - X)) where X = (x - 1) / (x + 1)
    # log(x) = 2 * (X + X**3 / 3 + X**5 / 5 + X**7 / 7 + ...)
    return BigDecimal(0) if x == 1

    if Rational === x
      x = (x - 1) / (x + 1)
      y = xn = BigDecimal(x, prec)
      x2 = BigDecimal(x.numerator ** 2)
      x2_denominator = BigDecimal(x.denominator ** 2)
      x2_exponent = x2.div(x2_denominator, 1).exponent
    else
      x = (x - 1).div(x + 1, prec)
      y = xn = x
      x2 = x.mult(x, prec)
      x2_exponent = x2.exponent
    end

    1.step do |i|
      n = prec + xn.exponent - y.exponent + x2_exponent
      break if n <= 0 || xn.zero?
      xn = xn.mult(x2, n)
      xn = xn.div(x2_denominator, n) if x2_denominator
      y = y.add(xn.div(2 * i + 1, n), prec)
    end
    y.mult(2, prec)
  end

  private_class_method def self._log_small_rational(x, prec)
    # Decompose x into (4/3)**n * (5/4)**m * y where y is close to 1.
    # Then calculate log(x) = n * log(4/3) + m * log(5/4) + log(y).
    logx = Math.log(x)
    x43 = 4 / 3r
    x54 = 5 / 4r
    log43 = Math.log(x43)
    log54 = Math.log(x54)
    diff = logx
    i43 = i54 = 0
    (logx / log43).ceil.times do |i|
      j = ((logx - log43 * i) / log54).round
      d = (logx - log43 * i - log54 * j).abs
      if d < diff
        diff = d
        i43 = i
        i54 = j
      end
    end
    y = x / (x43 ** i43 * x54 ** i54)
    _log_taylor(y, prec).add(i43 == 0 ? 0 : i43 * _log_taylor(x43, prec), prec).add(i54 == 0 ? 0 : i54 * _log_taylor(x54, prec), prec)
  end

  # call-seq:
  #   BigMath.log(decimal, numeric)    -> BigDecimal
  #
  # Computes the natural logarithm of +decimal+ to the specified number of
  # digits of precision, +numeric+.
  #
  # If +decimal+ is zero or negative, raises Math::DomainError.
  #
  # If +decimal+ is positive infinity, returns Infinity.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  def self.log(x, prec)
    _validate_prec(prec, :log)
    x = _coerce_to_bigdecimal(x, prec, :log, true)
    return _nan_computation_result if x.nan?
    raise Math::DomainError, 'Zero or negative argument for log' if x <= 0
    return _infinity_computation_result if x.infinite?
    return BigDecimal(0) if x == 1

    prec2 = prec + BigDecimal.double_fig

    if x >= 10 || x <= 0.1
      ln10 = _log_small_rational(10r, prec2)
      exponent = x.exponent
      x = x * BigDecimal("1e#{-x.exponent}")
      if x < 0.3
        x *= 10
        exponent -= 1
      end
      return ln10 * exponent + log(x, prec)
    end

    if x.n_significant_digits <= BigDecimal.double_fig && prec >= 50
      return _log_small_rational(x.to_r, prec2)
    end

    x_minus_one_exponent = (x - 1).exponent

    # log(x) = log(sqrt(sqrt(sqrt(sqrt(x))))) * 2**sqrt_steps
    sqrt_steps = [2 * Integer.sqrt(prec) + 3 * x_minus_one_exponent, 0].max

    # Reduce sqrt_step until sqrt gets fast
    # https://github.com/ruby/bigdecimal/pull/323
    # https://github.com/ruby/bigdecimal/pull/343
    sqrt_steps /= 10

    lg2 = 0.3010299956639812
    sqrt_prec = prec2 + [-x_minus_one_exponent, 0].max + (sqrt_steps * lg2).ceil

    sqrt_steps.times do
      x = x.sqrt(sqrt_prec)

      # Workaround for https://github.com/ruby/bigdecimal/issues/354
      x = x.mult(1, sqrt_prec)
    end

    _log_taylor(x, prec2).mult(2 ** sqrt_steps, prec2)
  end

  # call-seq:
  #   BigMath.exp(decimal, numeric)    -> BigDecimal
  #
  # Computes the value of e (the base of natural logarithms) raised to the
  # power of +decimal+, to the specified number of digits of precision.
  #
  # If +decimal+ is infinity, returns Infinity.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  def self.exp(x, prec)
    _validate_prec(prec, :exp)
    x = _coerce_to_bigdecimal(x, prec, :exp)
    return _nan_computation_result if x.nan?
    return x.positive? ? _infinity_computation_result : BigDecimal(0) if x.infinite?
    return BigDecimal(1) if x.zero?
    return BigDecimal(1).div(exp(-x, prec), prec) if x < 0

    # exp(x * 10**cnt) = exp(x)**(10**cnt)
    cnt = x > 1 ? x.exponent : 0
    prec2 = prec + BigDecimal.double_fig + cnt
    x *= BigDecimal("1e-#{cnt}")
    xn = BigDecimal(1)
    y = BigDecimal(1)

    # Taylor series for exp(x) around 0
    1.step do |i|
      n = prec2 + xn.exponent
      break if n <= 0 || xn.zero?
      x = x.mult(1, n)
      xn = xn.mult(x, n).div(i, n)
      y = y.add(xn, prec2)
    end

    # calculate exp(x * 10**cnt) from exp(x)
    # exp(x * 10**k) = exp(x * 10**(k - 1)) ** 10
    cnt.times do
      y2 = y.mult(y, prec2)
      y5 = y2.mult(y2, prec2).mult(y, prec2)
      y = y5.mult(y5, prec2)
    end

    y.mult(1, prec)
  end
end
