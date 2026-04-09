# frozen_string_literal: true
require 'bigdecimal'

#
#--
# Contents:
#   sqrt(x, prec)
#   cbrt(x, prec)
#   hypot(x, y, prec)
#   sin (x, prec)
#   cos (x, prec)
#   tan (x, prec)
#   asin(x, prec)
#   acos(x, prec)
#   atan(x, prec)
#   atan2(y, x, prec)
#   sinh (x, prec)
#   cosh (x, prec)
#   tanh (x, prec)
#   asinh(x, prec)
#   acosh(x, prec)
#   atanh(x, prec)
#   log2 (x, prec)
#   log10(x, prec)
#   log1p(x, prec)
#   expm1(x, prec)
#   erf (x, prec)
#   erfc(x, prec)
#   gamma(x, prec)
#   lgamma(x, prec)
#   frexp(x)
#   ldexp(x, exponent)
#   PI  (prec)
#   E   (prec) == exp(1.0,prec)
#
# where:
#   x, y ... BigDecimal number to be computed.
#   prec ... Number of digits to be obtained.
#++
#
# Provides mathematical functions.
#
# Example:
#
#   require "bigdecimal/math"
#
#   include BigMath
#
#   a = BigDecimal((PI(49)/2).to_s)
#   puts sin(a,100) # => 0.9999999999...9999999986e0
#
module BigMath
  module_function

  # call-seq:
  #   sqrt(decimal, numeric) -> BigDecimal
  #
  # Computes the square root of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  #   BigMath.sqrt(BigDecimal('2'), 32).to_s
  #   #=> "0.14142135623730950488016887242097e1"
  #
  def sqrt(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :sqrt)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :sqrt)
    x.sqrt(prec)
  end


  # Returns [sign, reduced_x] where reduced_x is in -pi/2..pi/2
  # and satisfies sin(x) = sign * sin(reduced_x)
  # If add_half_pi is true, adds pi/2 to x before reduction.
  # Precision of pi is adjusted to ensure reduced_x has the required precision.
  private_class_method def _sin_periodic_reduction(x, prec, add_half_pi: false) # :nodoc:
    return [1, x] if -Math::PI/2 <= x && x <= Math::PI/2 && !add_half_pi

    mod_prec = prec + BigDecimal::Internal::EXTRA_PREC
    pi_extra_prec = [x.exponent, 0].max + BigDecimal::Internal::EXTRA_PREC
    while true
      pi = PI(mod_prec + pi_extra_prec)
      half_pi = pi / 2
      div, mod = (add_half_pi ? x + pi : x + half_pi).divmod(pi)
      mod -= half_pi
      if mod.zero? || mod_prec + mod.exponent <= 0
        # mod is too small to estimate required pi precision
        mod_prec = mod_prec * 3 / 2 + BigDecimal::Internal::EXTRA_PREC
      elsif mod_prec + mod.exponent < prec
        # Estimate required precision of pi
        mod_prec = prec - mod.exponent + BigDecimal::Internal::EXTRA_PREC
      else
        return [div % 2 == 0 ? 1 : -1, mod.mult(1, prec)]
      end
    end
  end

  private_class_method def _sin_binary_splitting(x, prec) # :nodoc:
    return x if x.zero?
    x2 = x.mult(x, prec)
    # Find k that satisfies x2**k / (2k+1)! < 10**(-prec)
    log10 = Math.log(10)
    logx = BigDecimal::Internal.float_log(x.abs)
    step = (1..).bsearch { |k| Math.lgamma(2 * k + 1)[0] - 2 * k * logx > prec * log10 }
    # Construct denominator sequence for binary splitting
    # sin(x) = x*(1-x2/(2*3)*(1-x2/(4*5)*(1-x2/(6*7)*(1-x2/(8*9)*(1-...)))))
    ds = (1..step).map {|i| -(2 * i) * (2 * i + 1) }
    x.mult(1 + BigDecimal::Internal.taylor_sum_binary_splitting(x2, ds, prec), prec)
  end

  private_class_method def _sin_around_zero(x, prec) # :nodoc:
    # Divide x into several parts
    # sin(x.xxxxxxxx...) = sin(x.xx + 0.00xx + 0.0000xxxx + ...)
    # Calculate sin of each part and restore sin(0.xxxxxxxx...) using addition theorem.
    sin = BigDecimal(0)
    cos = BigDecimal(1)
    n = 2
    while x != 0 do
      partial_x = x.truncate(n)
      x -= partial_x
      s = _sin_binary_splitting(partial_x, prec)
      c = (1 - s * s).sqrt(prec)
      sin, cos = (sin * c).add(cos * s, prec), (cos * c).sub(sin * s, prec)
      n *= 2
    end
    sin.clamp(BigDecimal(-1), BigDecimal(1))
  end

  # call-seq:
  #   cbrt(decimal, numeric) -> BigDecimal
  #
  # Computes the cube root of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  #   BigMath.cbrt(BigDecimal('2'), 32).to_s
  #   #=> "0.12599210498948731647672106072782e1"
  #
  def cbrt(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :cbrt)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :cbrt)
    return BigDecimal::Internal.nan_computation_result if x.nan?
    return BigDecimal::Internal.infinity_computation_result * x.infinite? if x.infinite?
    return BigDecimal(0) if x.zero?

    x = -x if neg = x < 0
    ex = x.exponent / 3
    x = x._decimal_shift(-3 * ex)
    y = BigDecimal(Math.cbrt(x.to_f), 0)
    BigDecimal::Internal.newton_loop(prec + BigDecimal::Internal::EXTRA_PREC) do |p|
      y = (2 * y + x.div(y, p).div(y, p)).div(3, p)
    end
    y._decimal_shift(ex).mult(neg ? -1 : 1, prec)
  end

  # call-seq:
  #   hypot(x, y, numeric) -> BigDecimal
  #
  # Returns sqrt(x**2 + y**2) to the specified number of digits of
  # precision, +numeric+.
  #
  #   BigMath.hypot(BigDecimal('1'), BigDecimal('2'), 32).to_s
  #   #=> "0.22360679774997896964091736687313e1"
  #
  def hypot(x, y, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :hypot)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :hypot)
    y = BigDecimal::Internal.coerce_to_bigdecimal(y, prec, :hypot)
    return BigDecimal::Internal.nan_computation_result if x.nan? || y.nan?
    return BigDecimal::Internal.infinity_computation_result if x.infinite? || y.infinite?
    prec2 = prec + BigDecimal::Internal::EXTRA_PREC
    sqrt(x.mult(x, prec2) + y.mult(y, prec2), prec)
  end

  # call-seq:
  #   sin(decimal, numeric) -> BigDecimal
  #
  # Computes the sine of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is Infinity or NaN, returns NaN.
  #
  #   BigMath.sin(BigMath.PI(5)/4, 32).to_s
  #   #=> "0.70710807985947359435812921837984e0"
  #
  def sin(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :sin)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :sin)
    return BigDecimal::Internal.nan_computation_result if x.infinite? || x.nan?
    n = prec + BigDecimal::Internal::EXTRA_PREC
    sign, x = _sin_periodic_reduction(x, n)
    _sin_around_zero(x, n).mult(sign, prec)
  end

  # call-seq:
  #   cos(decimal, numeric) -> BigDecimal
  #
  # Computes the cosine of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is Infinity or NaN, returns NaN.
  #
  #   BigMath.cos(BigMath.PI(16), 32).to_s
  #   #=> "-0.99999999999999999999999999999997e0"
  #
  def cos(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :cos)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :cos)
    return BigDecimal::Internal.nan_computation_result if x.infinite? || x.nan?
    n = prec + BigDecimal::Internal::EXTRA_PREC
    sign, x = _sin_periodic_reduction(x, n, add_half_pi: true)
    _sin_around_zero(x, n).mult(sign, prec)
  end

  # call-seq:
  #   tan(decimal, numeric) -> BigDecimal
  #
  # Computes the tangent of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is Infinity or NaN, returns NaN.
  #
  #   BigMath.tan(BigDecimal("0.0"), 4).to_s
  #   #=> "0.0"
  #
  #   BigMath.tan(BigMath.PI(24) / 4, 32).to_s
  #   #=> "0.99999999999999999999999830836025e0"
  #
  def tan(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :tan)
    prec2 = prec + BigDecimal::Internal::EXTRA_PREC
    sin(x, prec2).div(cos(x, prec2), prec)
  end

  # call-seq:
  #   asin(decimal, numeric) -> BigDecimal
  #
  # Computes the arcsine of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.asin(BigDecimal('0.5'), 32).to_s
  #   #=> "0.52359877559829887307710723054658e0"
  #
  def asin(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :asin)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :asin)
    raise Math::DomainError, "Out of domain argument for asin" if x < -1 || x > 1
    return BigDecimal::Internal.nan_computation_result if x.nan?

    prec2 = prec + BigDecimal::Internal::EXTRA_PREC
    cos = (1 - x**2).sqrt(prec2)
    if cos.zero?
      PI(prec2).div(x > 0 ? 2 : -2, prec)
    else
      atan(x.div(cos, prec2), prec)
    end
  end

  # call-seq:
  #   acos(decimal, numeric) -> BigDecimal
  #
  # Computes the arccosine of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.acos(BigDecimal('0.5'), 32).to_s
  #   #=> "0.10471975511965977461542144610932e1"
  #
  def acos(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :acos)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :acos)
    raise Math::DomainError, "Out of domain argument for acos" if x < -1 || x > 1
    return BigDecimal::Internal.nan_computation_result if x.nan?

    prec2 = prec + BigDecimal::Internal::EXTRA_PREC
    return (PI(prec2) / 2).sub(asin(x, prec2), prec) if x < 0
    return PI(prec2).div(2, prec) if x.zero?

    sin = (1 - x**2).sqrt(prec2)
    atan(sin.div(x, prec2), prec)
  end

  # call-seq:
  #   atan(decimal, numeric) -> BigDecimal
  #
  # Computes the arctangent of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.atan(BigDecimal('-1'), 32).to_s
  #   #=> "-0.78539816339744830961566084581988e0"
  #
  def atan(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :atan)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :atan)
    return BigDecimal::Internal.nan_computation_result if x.nan?
    n = prec + BigDecimal::Internal::EXTRA_PREC
    return PI(n).div(2 * x.infinite?, prec) if x.infinite?

    x = -x if neg = x < 0
    x = BigDecimal(1).div(x, n) if inv = x < -1 || x > 1

    # Solve tan(y) - x = 0 with Newton's method
    # Repeat: y -= (tan(y) - x) * cos(y)**2
    y = BigDecimal(Math.atan(x.to_f), 0)
    BigDecimal::Internal.newton_loop(n) do |p|
      s = sin(y, p)
      c = (1 - s * s).sqrt(p)
      y = y.sub(c * (s.sub(c * x.mult(1, p), p)), p)
    end
    y = PI(n) / 2 - y if inv
    y.mult(neg ? -1 : 1, prec)
  end

  # call-seq:
  #   atan2(decimal, decimal, numeric) -> BigDecimal
  #
  # Computes the arctangent of y and x to the specified number of digits of
  # precision, +numeric+.
  #
  #   BigMath.atan2(BigDecimal('-1'), BigDecimal('1'), 32).to_s
  #   #=> "-0.78539816339744830961566084581988e0"
  #
  def atan2(y, x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :atan2)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :atan2)
    y = BigDecimal::Internal.coerce_to_bigdecimal(y, prec, :atan2)
    return BigDecimal::Internal.nan_computation_result if x.nan? || y.nan?

    if x.infinite? || y.infinite?
      one = BigDecimal(1)
      zero = BigDecimal(0)
      x = x.infinite? ? (x > 0 ? one : -one) : zero
      y = y.infinite? ? (y > 0 ? one : -one) : y.sign * zero
    end

    return x.sign >= 0 ? BigDecimal(0) : y.sign * PI(prec) if y.zero?

    y = -y if neg = y < 0
    xlarge = y.abs < x.abs
    prec2 = prec + BigDecimal::Internal::EXTRA_PREC
    if x > 0
      v = xlarge ? atan(y.div(x, prec2), prec) : PI(prec2) / 2 - atan(x.div(y, prec2), prec2)
    else
      v = xlarge ? PI(prec2) - atan(-y.div(x, prec2), prec2) : PI(prec2) / 2 + atan(x.div(-y, prec2), prec2)
    end
    v.mult(neg ? -1 : 1, prec)
  end

  # call-seq:
  #   sinh(decimal, numeric) -> BigDecimal
  #
  # Computes the hyperbolic sine of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.sinh(BigDecimal('1'), 32).to_s
  #   #=> "0.11752011936438014568823818505956e1"
  #
  def sinh(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :sinh)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :sinh)
    return BigDecimal::Internal.nan_computation_result if x.nan?
    return BigDecimal::Internal.infinity_computation_result * x.infinite? if x.infinite?

    prec2 = prec + BigDecimal::Internal::EXTRA_PREC
    prec2 -= x.exponent if x.exponent < 0
    e = exp(x, prec2)
    (e - BigDecimal(1).div(e, prec2)).div(2, prec)
  end

  # call-seq:
  #   cosh(decimal, numeric) -> BigDecimal
  #
  # Computes the hyperbolic cosine of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.cosh(BigDecimal('1'), 32).to_s
  #   #=> "0.15430806348152437784779056207571e1"
  #
  def cosh(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :cosh)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :cosh)
    return BigDecimal::Internal.nan_computation_result if x.nan?
    return BigDecimal::Internal.infinity_computation_result if x.infinite?

    prec2 = prec + BigDecimal::Internal::EXTRA_PREC
    e = exp(x, prec2)
    (e + BigDecimal(1).div(e, prec2)).div(2, prec)
  end

  # call-seq:
  #   tanh(decimal, numeric) -> BigDecimal
  #
  # Computes the hyperbolic tangent of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.tanh(BigDecimal('1'), 32).to_s
  #   #=> "0.76159415595576488811945828260479e0"
  #
  def tanh(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :tanh)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :tanh)
    return BigDecimal::Internal.nan_computation_result if x.nan?
    return BigDecimal(x.infinite?) if x.infinite?

    prec2 = prec + BigDecimal::Internal::EXTRA_PREC + [-x.exponent, 0].max
    e = exp(x, prec2)
    einv = BigDecimal(1).div(e, prec2)
    (e - einv).div(e + einv, prec)
  end

  # call-seq:
  #   asinh(decimal, numeric) -> BigDecimal
  #
  # Computes the inverse hyperbolic sine of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.asinh(BigDecimal('1'), 32).to_s
  #   #=> "0.88137358701954302523260932497979e0"
  #
  def asinh(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :asinh)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :asinh)
    return BigDecimal::Internal.nan_computation_result if x.nan?
    return BigDecimal::Internal.infinity_computation_result * x.infinite? if x.infinite?
    return -asinh(-x, prec) if x < 0

    sqrt_prec = prec + [-x.exponent, 0].max + BigDecimal::Internal::EXTRA_PREC
    log(x + sqrt(x**2 + 1, sqrt_prec), prec)
  end

  # call-seq:
  #   acosh(decimal, numeric) -> BigDecimal
  #
  # Computes the inverse hyperbolic cosine of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.acosh(BigDecimal('2'), 32).to_s
  #   #=> "0.1316957896924816708625046347308e1"
  #
  def acosh(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :acosh)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :acosh)
    raise Math::DomainError, "Out of domain argument for acosh" if x < 1
    return BigDecimal::Internal.infinity_computation_result if x.infinite?
    return BigDecimal::Internal.nan_computation_result if x.nan?

    log(x + sqrt(x**2 - 1, prec + BigDecimal::Internal::EXTRA_PREC), prec)
  end

  # call-seq:
  #   atanh(decimal, numeric) -> BigDecimal
  #
  # Computes the inverse hyperbolic tangent of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.atanh(BigDecimal('0.5'), 32).to_s
  #   #=> "0.54930614433405484569762261846126e0"
  #
  def atanh(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :atanh)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :atanh)
    raise Math::DomainError, "Out of domain argument for atanh" if x < -1 || x > 1
    return BigDecimal::Internal.nan_computation_result if x.nan?
    return BigDecimal::Internal.infinity_computation_result if x == 1
    return -BigDecimal::Internal.infinity_computation_result if x == -1

    prec2 = prec + BigDecimal::Internal::EXTRA_PREC
    (log(x + 1, prec2) - log(1 - x, prec2)).div(2, prec)
  end

  # call-seq:
  #   BigMath.log2(decimal, numeric)    -> BigDecimal
  #
  # Computes the base 2 logarithm of +decimal+ to the specified number of
  # digits of precision, +numeric+.
  #
  # If +decimal+ is zero or negative, raises Math::DomainError.
  #
  # If +decimal+ is positive infinity, returns Infinity.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.log2(BigDecimal('3'), 32).to_s
  #   #=> "0.15849625007211561814537389439478e1"
  #
  def log2(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :log2)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :log2)
    return BigDecimal::Internal.nan_computation_result if x.nan?
    return BigDecimal::Internal.infinity_computation_result if x.infinite? == 1

    prec2 = prec + BigDecimal::Internal::EXTRA_PREC * 3 / 2
    v = log(x, prec2).div(log(BigDecimal(2), prec2), prec2)
    # Perform half-up rounding to calculate log2(2**n)==n correctly in every rounding mode
    v = v.round(prec + BigDecimal::Internal::EXTRA_PREC - (v.exponent < 0 ? v.exponent : 0), BigDecimal::ROUND_HALF_UP)
    v.mult(1, prec)
  end

  # call-seq:
  #   BigMath.log10(decimal, numeric)    -> BigDecimal
  #
  # Computes the base 10 logarithm of +decimal+ to the specified number of
  # digits of precision, +numeric+.
  #
  # If +decimal+ is zero or negative, raises Math::DomainError.
  #
  # If +decimal+ is positive infinity, returns Infinity.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.log10(BigDecimal('3'), 32).to_s
  #   #=> "0.47712125471966243729502790325512e0"
  #
  def log10(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :log10)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :log10)
    return BigDecimal::Internal.nan_computation_result if x.nan?
    return BigDecimal::Internal.infinity_computation_result if x.infinite? == 1

    prec2 = prec + BigDecimal::Internal::EXTRA_PREC * 3 / 2
    v = log(x, prec2).div(log(BigDecimal(10), prec2), prec2)
    # Perform half-up rounding to calculate log10(10**n)==n correctly in every rounding mode
    v = v.round(prec + BigDecimal::Internal::EXTRA_PREC - (v.exponent < 0 ? v.exponent : 0), BigDecimal::ROUND_HALF_UP)
    v.mult(1, prec)
  end

  # call-seq:
  #   BigMath.log1p(decimal, numeric)    -> BigDecimal
  #
  # Computes log(1 + decimal) to the specified number of digits of precision, +numeric+.
  #
  #   BigMath.log1p(BigDecimal('0.1'), 32).to_s
  #   #=> "0.95310179804324860043952123280765e-1"
  #
  def log1p(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :log1p)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :log1p)
    raise Math::DomainError, 'Out of domain argument for log1p' if x < -1

    return log(x + 1, prec)
  end

  # call-seq:
  #   BigMath.expm1(decimal, numeric)    -> BigDecimal
  #
  # Computes exp(decimal) - 1 to the specified number of digits of precision, +numeric+.
  #
  #   BigMath.expm1(BigDecimal('0.1'), 32).to_s
  #   #=> "0.10517091807564762481170782649025e0"
  #
  def expm1(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :expm1)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :expm1)
    return BigDecimal(-1) if x.infinite? == -1

    exp_prec = prec
    if x < -1
      # log10(exp(x)) = x * log10(e)
      lg_e = 0.4342944819032518
      exp_prec = prec + (lg_e * x).ceil + BigDecimal::Internal::EXTRA_PREC
    elsif x < 1
      exp_prec = prec - x.exponent + BigDecimal::Internal::EXTRA_PREC
    else
      exp_prec = prec
    end

    return BigDecimal(-1) if exp_prec <= 0

    exp(x, exp_prec).sub(1, prec)
  end

  # call-seq:
  #   erf(decimal, numeric) -> BigDecimal
  #
  # Computes the error function of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.erf(BigDecimal('1'), 32).to_s
  #   #=> "0.84270079294971486934122063508261e0"
  #
  def erf(x, prec)
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
      erfc = _erfc_asymptotic(x, erfc_prec)
      return BigDecimal(1).sub(erfc, prec) if erfc
    end

    prec2 = prec + BigDecimal::Internal::EXTRA_PREC
    x_smallprec = x.mult(1, Integer.sqrt(prec2) / 2)
    # Taylor series of x with small precision is fast
    erf1 = _erf_taylor(x_smallprec, BigDecimal(0), BigDecimal(0), prec2)
    # Taylor series converges quickly for small x
    _erf_taylor(x - x_smallprec, x_smallprec, erf1, prec2).mult(1, prec)
  end

  # call-seq:
  #   erfc(decimal, numeric) -> BigDecimal
  #
  # Computes the complementary error function of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.erfc(BigDecimal('10'), 32).to_s
  #   #=> "0.20884875837625447570007862949578e-44"
  #
  def erfc(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :erfc)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :erfc)
    return BigDecimal::Internal.nan_computation_result if x.nan?
    return BigDecimal(1 - x.infinite?) if x.infinite?
    return BigDecimal(1).sub(erf(x, prec + BigDecimal::Internal::EXTRA_PREC), prec) if x < 0.5
    return BigDecimal::Internal.underflow_computation_result if x > 5000000000 # erfc(5000000000) < 1e-10000000000000000000 (underflow)

    if x >= 8
      y = _erfc_asymptotic(x, prec)
      return y.mult(1, prec) if y
    end

    # erfc(x) = 1 - erf(x) < exp(-x**2)/x/sqrt(pi)
    # Precision of erf(x) needs about log10(exp(-x**2)/x/sqrt(pi)) extra digits
    log10 = 2.302585092994046
    xf = x.to_f
    high_prec = prec + BigDecimal::Internal::EXTRA_PREC + ((xf**2 + Math.log(xf) + Math.log(Math::PI)/2) / log10).ceil
    BigDecimal(1).sub(erf(x, high_prec), prec)
  end

  # Calculates erf(x + a)
  private_class_method def _erf_taylor(x, a, erf_a, prec) # :nodoc:
    return erf_a if x.zero?
    # Let f(x+a) = erf(x+a)*exp((x+a)**2)*sqrt(pi)/2
    #            = c0 + c1*x + c2*x**2 + c3*x**3 + c4*x**4 + ...
    # f'(x+a) = 1+2*(x+a)*f(x+a)
    # f'(x+a) = c1 + 2*c2*x + 3*c3*x**2 + 4*c4*x**3 + 5*c5*x**4 + ...
    #         = 1+2*(x+a)*(c0 + c1*x + c2*x**2 + c3*x**3 + c4*x**4 + ...)
    # therefore,
    # c0 = f(a)
    # c1 = 2 * a * c0 + 1
    # c2 = (2 * c0 + 2 * a * c1) / 2
    # c3 = (2 * c1 + 2 * a * c2) / 3
    # c4 = (2 * c2 + 2 * a * c3) / 4
    #
    # All coefficients are positive when a >= 0

    scale = BigDecimal(2).div(sqrt(PI(prec), prec), prec)
    c_prev = erf_a.div(scale.mult(exp(-a*a, prec), prec), prec)
    c_next = (2 * a * c_prev).add(1, prec).mult(x, prec)
    sum = c_prev.add(c_next, prec)

    2.step do |k|
      cn = (c_prev.mult(x, prec) + a * c_next).mult(2, prec).mult(x, prec).div(k, prec)
      sum = sum.add(cn, prec)
      c_prev, c_next = c_next, cn
      break if [c_prev, c_next].all? { |c| c.zero?  || (c.exponent < sum.exponent - prec) }
    end
    value = sum.mult(scale.mult(exp(-(x + a).mult(x + a, prec), prec), prec), prec)
    value > 1 ? BigDecimal(1) : value
  end

  private_class_method def _erfc_asymptotic(x, prec) # :nodoc:
    # Let f(x) = erfc(x)*sqrt(pi)*exp(x**2)/2
    # f(x) satisfies the following differential equation:
    # 2*x*f(x) = f'(x) + 1
    # From the above equation, we can derive the following asymptotic expansion:
    # f(x) = (0..kmax).sum { (-1)**k * (2*k)! / 4**k / k! / x**(2*k)) } / x

    # This asymptotic expansion does not converge.
    # But if there is a k that satisfies (2*k)! / 4**k / k! / x**(2*k) < 10**(-prec),
    # It is enough to calculate erfc within the given precision.
    # Using Stirling's approximation, we can simplify this condition to:
    # sqrt(2)/2 + k*log(k) - k - 2*k*log(x) < -prec*log(10)
    # and the left side is minimized when k = x**2.
    prec += BigDecimal::Internal::EXTRA_PREC
    xf = x.to_f
    kmax = (1..(xf ** 2).floor).bsearch do |k|
      Math.log(2) / 2 + k * Math.log(k) - k - 2 * k * Math.log(xf) < -prec * Math.log(10)
    end
    return unless kmax

    sum = BigDecimal(1)
    # To calculate `exp(x2, prec)`, x2 needs extra log10(x**2) digits of precision
    x2 = x.mult(x, prec + (2 * Math.log10(xf)).ceil)
    d = BigDecimal(1)
    (1..kmax).each do |k|
      d = d.div(x2, prec).mult(1 - 2 * k, prec).div(2, prec)
      sum = sum.add(d, prec)
    end
    sum.div(exp(x2, prec).mult(PI(prec).sqrt(prec), prec), prec).div(x, prec)
  end

  # call-seq:
  #   BigMath.gamma(decimal, numeric)    -> BigDecimal
  #
  # Computes the gamma function of +decimal+ to the specified number of
  # digits of precision, +numeric+.
  #
  #   BigMath.gamma(BigDecimal('0.5'), 32).to_s
  #   #=> "0.17724538509055160272981674833411e1"
  #
  def gamma(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :gamma)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :gamma)
    prec2 = prec + BigDecimal::Internal::EXTRA_PREC
    if x < 0.5
      raise Math::DomainError, 'Numerical argument is out of domain - gamma' if x.frac.zero?

      # Euler's reflection formula: gamma(z) * gamma(1-z) = pi/sin(pi*z)
      pi = PI(prec2)
      sin = _sinpix(x, pi, prec2)
      return pi.div(gamma(1 - x, prec2).mult(sin, prec2), prec)
    elsif x.frac.zero? && x < 1000 * prec
      return _gamma_positive_integer(x, prec2).mult(1, prec)
    end

    a, sum = _gamma_spouge_sum_part(x, prec2)
    (x + (a - 1)).power(x - 0.5, prec2).mult(BigMath.exp(1 - x, prec2), prec2).mult(sum, prec)
  end

  # Calculates prod{x-k} and its coefficients for given ks, xn and prec with baby-step giant-step method.
  # xn is an array of precalculated powers of x: [1, x, x**2, x**3, ...]
  private_class_method def _x_minus_k_prod_coef(ks, xn, prec) # :nodoc:
    coef = [1]
    ks.each do |k|
      coef_next = [0] * (coef.size + 1)
      coef.each_with_index do |c, i|
        coef_next[i] -= k * c
        coef_next[i + 1] += c
      end
      coef = coef_next
    end

    prd = coef.each_with_index.map do |c, i|
      xn[i].mult(c, prec)
    end.reduce do |sum, value|
      sum.add(value, prec)
    end
    [prd, coef]
  end

  # Calculate approximate gamma by Lagrange interpolation of f(x) = b**x / x!
  # Nodes are placed at x_i = b-l, b-l+1, ..., b+l.
  #
  # Mathematically, we use the barycentric interpolation form:
  # f(x) \approx \omega(x) \sum_{i} \frac{w_i f(x_i)}{x - x_i}
  # Therefore, \Gamma(x+1) = x! = b**x / f(x)
  #
  # Estimated time complexity:
  # - O(N * log^3 N) for small-digit/rational x (Binary Splitting)
  # - O(N^2) for full-digit x (Baby-step Giant-step)
  # Precondition: 0 < x < const * (prec / prec.bit_length)**2
  private_class_method def _gamma_lagrange(x, prec) # :nodoc:
    x = BigDecimal(x) - 1
    l = prec

    # Shift x to ensure the scaled bell curve b**x/x! is wide enough to cover
    # all 2*l+1 interpolation nodes without losing significant digits.
    shift = x < 2 * prec ? 2 * prec - x.floor : 0
    x += shift
    b = x.round

    # c0 represents the common large factorial part factored out from the weights
    # to avoid computing massive numbers in every term.
    c0s = [*(1..b-l), *(1..2*l)]
    c0s = c0s.each_slice(2).map {|a, b| b ? BigDecimal(a).mult(b, prec) : BigDecimal(a) } while c0s.size != 1
    c0 = c0s.first

    # --- Reference: Naive interpolation logic ---
    # Optimize this calculation for full-digit-x case and small-digit-x case.
    # sum = BigDecimal(0)
    # prod = [*(b-l)..(b+l), *(0...shift)].map {|i| x - i }.reduce { _1.mult(_2, prec) }
    # c = BigDecimal(1) # represents w_i * f(x_i) (normalized)
    # ((b-l)..(b+l)).each do |i|
    #   if i != b - l
    #     c = c.mult(-b * (b + l - i + 1), prec).div((i - b + l) * i, prec)
    #   end
    #   sum = sum.add(c.div(x - i, prec), prec)
    # end
    # --------------------------------------------

    if x.n_significant_digits > prec / prec.bit_length
      # Reduce full-precision multiplications/divisions by Baby-Step Giant-Step method

      batch_size = prec.bit_length
      # When expanding prod{x-k}, the coefficient of x**n might be huge.
      # Increase internal calculation precision to avoid catastrophic cancellation.
      internal_xn_prec = prec + (Math.log10(b + l) * batch_size).ceil
      xn = [BigDecimal(1)]
      xn << xn.last.mult(x, internal_xn_prec) while xn.size <= batch_size

      c = BigDecimal(1)
      sum = BigDecimal(0)
      prod = BigDecimal(1)

      ((b-l)..(b+l)).to_a.each_slice(batch_size) do |batch_ks|
        # Calculate prod{x-k} in this batch
        batch_prod, prod_coef = _x_minus_k_prod_coef(batch_ks, xn, internal_xn_prec)

        # Calculate coefficients of batch_prod / (x-k) using Synthetic Division (Ruffini's rule)
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
        sum = sum.add(batch_sum.mult(c, prec).div(batch_prod, prec), prec)
        c = c.mult(c_scale.numerator, prec).div(c_scale.denominator, prec)
        prod = prod.mult(batch_prod, prec)
      end

      # Perform shift.times {|i| prod = prod.mult(x - i, prec) } with batch processing
      shift.times.to_a.each_slice(batch_size) do |batch_ks|
        shift_prod, _prod_coef = _x_minus_k_prod_coef(batch_ks, xn, internal_xn_prec)
        prod = prod.mult(shift_prod, prec)
      end
    else
      # Binary Splitting Method (BSM) for short-digit inputs
      prods = ((b-l)..(b+l)).map {|i| x - i } + shift.times.map {|i| x - i }
      prods = prods.each_slice(2).map {|a, b| b ? a.mult(b, prec) : a } while prods.size != 1
      prod = prods.first

      # State represents: [Base_Denominator, Numerator, Denominator_Multiplier]
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
    BigDecimal(b).power(x - (b - l), prec).div(prod.mult(sum, prec), prec).mult(c0, prec)
  end

  # call-seq:
  #   BigMath.lgamma(decimal, numeric)    -> [BigDecimal, Integer]
  #
  # Computes the natural logarithm of the absolute value of the gamma function
  # of +decimal+ to the specified number of digits of precision, +numeric+ and its sign.
  #
  #   BigMath.lgamma(BigDecimal('0.5'), 32)
  #   #=> [0.57236494292470008707171367567653e0, 1]
  #
  def lgamma(x, prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :lgamma)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :lgamma)
    prec2 = prec + BigDecimal::Internal::EXTRA_PREC
    if x < 0.5
      return [BigDecimal::INFINITY, 1] if x.frac.zero?

      loop do
        # Euler's reflection formula: gamma(z) * gamma(1-z) = pi/sin(pi*z)
        pi = PI(prec2)
        sin = _sinpix(x, pi, prec2)
        log_gamma = BigMath.log(pi, prec2).sub(lgamma(1 - x, prec2).first + BigMath.log(sin.abs, prec2), prec)
        return [log_gamma, sin > 0 ? 1 : -1] if prec2 + log_gamma.exponent > prec + BigDecimal::Internal::EXTRA_PREC

        # Retry with higher precision if loss of significance is too large
        prec2 = prec2 * 3 / 2
      end
    elsif x.frac.zero? && x < 1000 * prec
      log_gamma = BigMath.log(_gamma_positive_integer(x, prec2), prec)
      [log_gamma, 1]
    else
      # if x is close to 1 or 2, increase precision to reduce loss of significance
      diff1_exponent = (x - 1).exponent
      diff2_exponent = (x - 2).exponent
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
      a, sum = _gamma_spouge_sum_part(x, prec2)
      log_gamma = BigMath.log(sum, prec2).add((x - 0.5).mult(BigMath.log(x.add(a - 1, prec2), prec2), prec2) + 1 - x, prec)
      [log_gamma, 1]
    end
  end

  # Returns sum part: sqrt(2*pi) and c[k]/(x+k) terms of Spouge's approximation
  private_class_method def _gamma_spouge_sum_part(x, prec) # :nodoc:
    x -= 1
    # Spouge's approximation
    # x! = (x + a)**(x + 0.5) * exp(-x - a) * (sqrt(2 * pi)  + (1..a - 1).sum{|k| c[k] / (x + k) } + epsilon)
    # where c[k] = (-1)**k * (a - k)**(k - 0.5) * exp(a - k) / (k - 1)!
    # and epsilon is bounded by a**(-0.5) * (2 * pi) ** (-a - 0.5)

    # Estimate required a for given precision
    a = (prec / Math.log10(2 * Math::PI)).ceil

    # Calculate exponent of c[k] in low precision to estimate required precision
    low_prec = 16
    log10f = Math.log(10)
    x_low_prec = x.mult(1, low_prec)
    loggamma_k = 0
    ck_exponents = (1..a-1).map do |k|
      loggamma_k += Math.log10(k - 1) if k > 1
      -loggamma_k - k / log10f + (k - 0.5) * Math.log10(a - k) - BigDecimal::Internal.float_log(x_low_prec.add(k, low_prec)) / log10f
    end

    # Estimate exponent of sum by Stirling's approximation
    approx_sum_exponent = x < 1 ? -Math.log10(a) / 2 : Math.log10(2 * Math::PI) / 2 + x_low_prec.add(0.5, low_prec) * Math.log10(x_low_prec / x_low_prec.add(a, low_prec))

    # Determine required precision of c[k]
    prec2 = [ck_exponents.max.ceil - approx_sum_exponent.floor, 0].max + prec

    einv = BigMath.exp(-1, prec2)
    sum = (PI(prec) * 2).sqrt(prec).mult(BigMath.exp(-a, prec), prec)
    y = BigDecimal(1)
    (1..a - 1).each do |k|
      # c[k] = (-1)**k * (a - k)**(k - 0.5) * exp(-k) / (k-1)! / (x + k)
      y = y.div(1 - k, prec2) if k > 1
      y = y.mult(einv, prec2)
      z = y.mult(BigDecimal((a - k) ** k), prec2).div(BigDecimal(a - k).sqrt(prec2).mult(x.add(k, prec2), prec2), prec2)
      # sum += c[k] / (x + k)
      sum = sum.add(z, prec2)
    end
    [a, sum]
  end

  private_class_method def _gamma_positive_integer(x, prec) # :nodoc:
    return x if x == 1
    numbers = (1..x - 1).map {|i| BigDecimal(i) }
    while numbers.size > 1
      numbers = numbers.each_slice(2).map {|a, b| b ? a.mult(b, prec) : a }
    end
    numbers.first
  end

  # Returns sin(pi * x), for gamma reflection formula calculation
  private_class_method def _sinpix(x, pi, prec) # :nodoc:
    x = x % 2
    sign = x > 1 ? -1 : 1
    x %= 1
    x = 1 - x if x > 0.5 # to avoid sin(pi*x) loss of precision for x close to 1
    sign * sin(x.mult(pi, prec), prec)
  end

  # call-seq:
  #   frexp(x) -> [BigDecimal, Integer]
  #
  # Decomposes +x+ into a normalized fraction and an integral power of ten.
  #
  #   BigMath.frexp(BigDecimal(123.456))
  #   #=> [0.123456e0, 3]
  #
  def frexp(x)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, 0, :frexp)
    return [x, 0] unless x.finite?

    exponent = x.exponent
    [x._decimal_shift(-exponent), exponent]
  end

  # call-seq:
  #   ldexp(fraction, exponent) -> BigDecimal
  #
  # Inverse of +frexp+.
  # Returns the value of fraction * 10**exponent.
  #
  #   BigMath.ldexp(BigDecimal("0.123456e0"), 3)
  #   #=> 0.123456e3
  #
  def ldexp(x, exponent)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, 0, :ldexp)
    x.finite? ? x._decimal_shift(exponent) : x
  end

  # call-seq:
  #   PI(numeric) -> BigDecimal
  #
  # Computes the value of pi to the specified number of digits of precision,
  # +numeric+.
  #
  #   BigMath.PI(32).to_s
  #   #=> "0.31415926535897932384626433832795e1"
  #
  def PI(prec)
    # Gauss–Legendre algorithm
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :PI)
    n = prec + BigDecimal::Internal::EXTRA_PREC
    a = BigDecimal(1)
    b = BigDecimal(0.5, 0).sqrt(n)
    s = BigDecimal(0.25, 0)
    t = 1
    while a != b && (a - b).exponent > 1 - n
      c = (a - b).div(2, n)
      a, b = (a + b).div(2, n), (a * b).sqrt(n)
      s = s.sub(c * c * t, n)
      t *= 2
    end
    (a * b).div(s, prec)
  end

  # call-seq:
  #   E(numeric) -> BigDecimal
  #
  # Computes e (the base of natural logarithms) to the specified number of
  # digits of precision, +numeric+.
  #
  #   BigMath.E(32).to_s
  #   #=> "0.27182818284590452353602874713527e1"
  #
  def E(prec)
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :E)
    exp(1, prec)
  end
end
