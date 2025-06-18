if RUBY_ENGINE == 'jruby'
  JRuby::Util.load_ext("org.jruby.ext.bigdecimal.BigDecimalLibrary")
else
  require 'bigdecimal.so'
end

class BigDecimal

  # Returns the square root of the value.
  #
  # Result has at least prec significant digits.
  #
  def sqrt(prec)
    if infinite? == 1
      exception_mode = BigDecimal.mode(BigDecimal::EXCEPTION_ALL)
      raise FloatDomainError, "Computation results in 'Infinity'" if exception_mode.anybits?(BigDecimal::EXCEPTION_INFINITY)
      return INFINITY
    end
    raise ArgumentError, 'negative precision' if prec < 0
    raise FloatDomainError, 'sqrt of negative value' if self < 0
    raise FloatDomainError, "sqrt of 'NaN'(Not a Number)" if nan?

    n_digits = n_significant_digits
    prec = [prec, n_digits].max

    if n_digits < prec / 2
      # Fast path for sqrt(16e100) => 4e50
      ex = (n_digits - exponent + 1) / 2
      n = (self * BigDecimal("1e#{2 * ex}")).to_i
      sqrt = Integer.sqrt(n)
      return BigDecimal(sqrt) * BigDecimal("1e#{-ex}") if sqrt * sqrt == n
    end

    ex = prec + BigDecimal.double_fig - exponent / 2
    sqrt = Integer.sqrt(self * BigDecimal("1e#{2 * ex}"))
    BigDecimal(sqrt) * BigDecimal("1e#{-ex}")
  end
end
