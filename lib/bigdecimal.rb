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

    prec = [prec, n_significant_digits].max
    ex = prec + BigDecimal.double_fig - exponent / 2
    base = BigDecimal(10) ** ex
    sqrt = Integer.sqrt(self * base * base)
    BigDecimal(sqrt).div(base, prec + BigDecimal.double_fig)
  end
end
