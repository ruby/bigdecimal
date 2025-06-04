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
    unless y.is_a?(BigDecimal)
      case y
      when Integer, Float, Rational
        y = BigDecimal(y, 0)
      when nil
        raise TypeError, 'wrong argument type NilClass'
      else
        x, y = y.coerce(self)
        return x**y
      end
    end
    power(y)
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
    y = BigMath._coerce_to_bigdecimal(y, :power)

    return BigDecimal::NAN if x.nan? || y.nan?

    if x.zero?
      return BigDecimal(1) if y.zero?
      return BigDecimal(0) if y > 0
      if y.frac.zero? && y % 2 == 1 && x.sign == -1
        return -BigDecimal::INFINITY
      else
        return BigDecimal::INFINITY
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

    if y.infinite?
      if x < 1
        return y.positive? ? BigDecimal(0) : BigDecimal::INFINITY
      else
        return y.positive? ? BigDecimal::INFINITY : BigDecimal(0)
      end
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
          return ((xn.exponent > 0) ^ neg ? BigDecimal::INFINITY : BigDecimal(0)) * (int_part.even? || x > 0 ? 1 : -1)
        end
      end
      return neg ? BigDecimal(1) / ans : ans
    end

    prec ||= [x.n_significant_digits, y.n_significant_digits, BigDecimal.double_fig].max + BigDecimal.double_fig

    if y < 0
      inv = x.power(-y, prec)
      return BigDecimal(0) if inv.infinite?
      return BigDecimal::INFINITY if inv.zero?
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
  def self._coerce_to_bigdecimal(x, method_name, complex_domain_error = false)
    case x
    when BigDecimal
      return x
    when Integer, Float, Rational
      return BigDecimal(x, 0)
    when Complex
      if complex_domain_error
        raise Math::DomainError, "Complex argument for BigMath.#{method_name}"
      end
    end
    raise ArgumentError, "#{x.inspect} can't be coerced into BigDecimal"
  end

  def self._validate_prec(prec, method_name)
    raise ArgumentError, 'precision must be an Integer' unless Integer === prec
    raise ArgumentError, "Zero or negative precision for #{method_name}" if prec <= 0
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
    x = _coerce_to_bigdecimal(x, :log, true)
    return BigDecimal::NAN if x.nan?
    raise Math::DomainError, 'Zero or negative argument for log' if x <= 0
    return BigDecimal::INFINITY if x.infinite?
    return BigDecimal(0) if x == 1

    if x > 10 || x < 0.1
      log10 = log(BigDecimal(10), prec)
      exponent = x.exponent
      x = x * BigDecimal("1e#{-x.exponent}")
      if x > 3
        x /= 10
        exponent += 1
      end
      return log10 * exponent + log(x, prec)
    end

    x_minus_one_exponent = (x - 1).exponent
    prec += BigDecimal.double_fig

    # log(x) = log(sqrt(sqrt(sqrt(sqrt(x))))) * 2**sqrt_steps
    sqrt_steps = [2 * Integer.sqrt(prec) + 3 * x_minus_one_exponent, 0].max

    # Reduce sqrt_step until sqrt gets fast
    # https://github.com/ruby/bigdecimal/pull/323
    # https://github.com/ruby/bigdecimal/pull/343
    sqrt_steps /= 10

    prec2 = prec + [-x_minus_one_exponent, 0].max + (sqrt_steps * 0.3010299956639812).ceil

    sqrt_steps.times do
      x = x.sqrt(prec2)

      # Workaround for https://github.com/ruby/bigdecimal/issues/354
      x = x.mult(1, prec2 + BigDecimal.double_fig)
    end

    # Taylor series for log(x) around 1
    # log(x) = -log((1 + X) / (1 - X)) where X = (x - 1) / (x + 1)
    # log(x) = 2 * (X + X**3 / 3 + X**5 / 5 + X**7 / 7 + ...)
    x = (x - 1).div(x + 1, prec2)
    y = x
    x2 = x.mult(x, prec)
    1.step do |i|
      n = prec + x.exponent - y.exponent + x2.exponent
      break if n <= 0 || x.zero?
      x = x.mult(x2.round(n - x2.exponent), n)
      y = y.add(x.div(2 * i + 1, n), prec)
    end

    y.mult(2 ** (sqrt_steps + 1), prec)
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
    x = _coerce_to_bigdecimal(x, :exp)
    return BigDecimal::NAN if x.nan?
    return x.positive? ? BigDecimal::INFINITY : BigDecimal(0) if x.infinite?
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
