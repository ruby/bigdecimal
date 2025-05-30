# frozen_string_literal: false
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

    mod_prec = prec + BigDecimal.double_fig
    pi_extra_prec = [x.exponent, 0].max + BigDecimal.double_fig
    while true
      pi = PI(mod_prec + pi_extra_prec)
      half_pi = pi / 2
      div, mod = (add_half_pi ? x + pi : x + half_pi).divmod(pi)
      mod -= half_pi
      if mod.zero? || mod_prec + mod.exponent <= 0
        # mod is too small to estimate required pi precision
        mod_prec = mod_prec * 3 / 2 + BigDecimal.double_fig
      elsif mod_prec + mod.exponent < prec
        # Estimate required precision of pi
        mod_prec = prec - mod.exponent + BigDecimal.double_fig
      else
        return [div % 2 == 0 ? 1 : -1, mod.mult(1, prec)]
      end
    end
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
    y = BigDecimal(Math.cbrt(x.to_f))
    precs = [prec + BigDecimal.double_fig]
    precs << 2 + precs.last / 2 while precs.last > BigDecimal.double_fig
    precs.reverse_each do |p|
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
    prec2 = prec + BigDecimal.double_fig
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
    n    = prec + BigDecimal.double_fig
    one  = BigDecimal("1")
    two  = BigDecimal("2")
    sign, x = _sin_periodic_reduction(x, n)
    x1   = x
    x2   = x.mult(x,n)
    y    = x
    d    = y
    i    = one
    z    = one
    while d.nonzero? && ((m = n - (y.exponent - d.exponent).abs) > 0)
      m = BigDecimal.double_fig if m < BigDecimal.double_fig
      x1  = -x2.mult(x1,n)
      i  += two
      z  *= (i-one) * i
      d   = x1.div(z,m)
      y  += d
    end
    y = BigDecimal("1") if y > 1
    y.mult(sign, prec)
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
    sign, x = _sin_periodic_reduction(x, prec + BigDecimal.double_fig, add_half_pi: true)
    sign * sin(x, prec)
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
    sin(x, prec + BigDecimal.double_fig).div(cos(x, prec + BigDecimal.double_fig), prec)
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

    prec2 = prec + BigDecimal.double_fig
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

    prec2 = prec + BigDecimal.double_fig
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
    n = prec + BigDecimal.double_fig
    pi = PI(n)
    x = -x if neg = x < 0
    return pi.div(neg ? -2 : 2, prec) if x.infinite?
    return pi.div(neg ? -4 : 4, prec) if x.round(prec) == 1
    x = BigDecimal("1").div(x, n) if inv = x > 1
    x = (-1 + sqrt(1 + x.mult(x, n), n)).div(x, n) if dbl = x > 0.5
    y = x
    d = y
    t = x
    r = BigDecimal("3")
    x2 = x.mult(x,n)
    while d.nonzero? && ((m = n - (y.exponent - d.exponent).abs) > 0)
      m = BigDecimal.double_fig if m < BigDecimal.double_fig
      t = -t.mult(x2,n)
      d = t.div(r,m)
      y += d
      r += 2
    end
    y *= 2 if dbl
    y = pi / 2 - y if inv
    y = -y if neg
    y.mult(1, prec)
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
    prec2 = prec + BigDecimal.double_fig
    if x > 0
      v = xlarge ? atan(y.div(x, prec2), prec) : PI(prec2) / 2 - atan(x.div(y, prec2), prec2)
    else
      v = xlarge ? PI(prec2) - atan(-y.div(x, prec2), prec2) : PI(prec2) / 2 + atan(x.div(-y, prec2), prec2)
    end
    v.mult(neg ? -1 : 1, prec)
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
    prec = BigDecimal::Internal.coerce_validate_prec(prec, :PI)
    n      = prec + BigDecimal.double_fig
    zero   = BigDecimal("0")
    one    = BigDecimal("1")
    two    = BigDecimal("2")

    m25    = BigDecimal("-0.04")
    m57121 = BigDecimal("-57121")

    pi     = zero

    d = one
    k = one
    t = BigDecimal("-80")
    while d.nonzero? && ((m = n - (pi.exponent - d.exponent).abs) > 0)
      m = BigDecimal.double_fig if m < BigDecimal.double_fig
      t   = t*m25
      d   = t.div(k,m)
      k   = k+two
      pi  = pi + d
    end

    d = one
    k = one
    t = BigDecimal("956")
    while d.nonzero? && ((m = n - (pi.exponent - d.exponent).abs) > 0)
      m = BigDecimal.double_fig if m < BigDecimal.double_fig
      t   = t.div(m57121,n)
      d   = t.div(k,m)
      pi  = pi + d
      k   = k+two
    end
    pi.mult(1, prec)
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
    BigMath.exp(1, prec)
  end
end
