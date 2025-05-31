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
#   sinh (x, prec)
#   cosh (x, prec)
#   tanh (x, prec)
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
#   a = BigDecimal((PI(100)/2).to_s)
#   puts sin(a,100) # => 0.99999999999999999999......e0
#
module BigMath
  module_function

  # call-seq:
  #   sqrt(decimal, numeric) -> BigDecimal
  #
  # Computes the square root of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  #   BigMath.sqrt(BigDecimal('2'), 16).to_s
  #   #=> "0.1414213562373095048801688724e1"
  #
  def sqrt(x, prec)
    x.sqrt(prec)
  end

  # call-seq:
  #   cbrt(decimal, numeric) -> BigDecimal
  #
  # Computes the cube root of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  #   BigMath.cbrt(BigDecimal('2'), 16).to_s
  #   #=> "0.125992104989487316476721060727822e1"
  #
  def cbrt(x, prec)
    raise ArgumentError, "Zero or negative precision for cbrt" if prec <= 0
    return x if x.zero? || x.infinite? || x.nan?
    return -cbrt(-x, prec) if x < 0

    ex = x.exponent / 3
    x *= BigDecimal("1e#{-ex * 3}")
    y = BigDecimal(Math.cbrt(x.to_f))
    precs = [prec + BigDecimal.double_fig]
    precs << 2 + precs.last / 2 while precs.last > BigDecimal.double_fig
    precs.reverse_each do |p|
      y = (2 * y + x.div(y, p).div(y, p)).div(3, p)
    end
    y * BigDecimal("1e#{ex}")
  end

  # call-seq:
  #   hypot(x, y, numeric) -> BigDecimal
  #
  # Returns sqrt(x**2 + y**2) to the specified number of digits of
  # precision, +numeric+.
  #
  #   BigMath.hypot(BigDecimal('1'), BigDecimal('2'), 16).to_s
  #   #=> "0.2236067977499789696409173668333333334e1"
  #
  def hypot(x, y, prec)
    return BigDecimal::NAN if x.nan? || y.nan?
    return BigDecimal::INFINITY if x.infinite? || y.infinite?
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
  #   BigMath.sin(BigMath.PI(5)/4, 5).to_s
  #   #=> "0.70710678118654752440082036563292800375e0"
  #
  def sin(x, prec)
    raise ArgumentError, "Zero or negative precision for sin" if prec <= 0
    return BigDecimal("NaN") if x.infinite? || x.nan?
    n    = prec + BigDecimal.double_fig
    one  = BigDecimal("1")
    two  = BigDecimal("2")
    x = -x if neg = x < 0
    if x > 6
      twopi = two * BigMath.PI(prec + x.exponent)
      if x > 30
        x %= twopi
      else
        x -= twopi while x > twopi
      end
    end
    x1   = x
    x2   = x.mult(x,n)
    sign = 1
    y    = x
    d    = y
    i    = one
    z    = one
    while d.nonzero? && ((m = n - (y.exponent - d.exponent).abs) > 0)
      m = BigDecimal.double_fig if m < BigDecimal.double_fig
      sign = -sign
      x1  = x2.mult(x1,n)
      i  += two
      z  *= (i-one) * i
      d   = sign * x1.div(z,m)
      y  += d
    end
    y = BigDecimal("1") if y > 1
    neg ? -y : y
  end

  # call-seq:
  #   cos(decimal, numeric) -> BigDecimal
  #
  # Computes the cosine of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is Infinity or NaN, returns NaN.
  #
  #   BigMath.cos(BigMath.PI(4), 16).to_s
  #   #=> "-0.999999999999999999999999999999856613163740061349e0"
  #
  def cos(x, prec)
    raise ArgumentError, "Zero or negative precision for cos" if prec <= 0
    return BigDecimal("NaN") if x.infinite? || x.nan?
    n    = prec + BigDecimal.double_fig
    one  = BigDecimal("1")
    two  = BigDecimal("2")
    x = -x if x < 0
    if x > 6
      twopi = two * BigMath.PI(prec + x.exponent)
      if x > 30
        x %= twopi
      else
        x -= twopi while x > twopi
      end
    end
    x1 = one
    x2 = x.mult(x,n)
    sign = 1
    y = one
    d = y
    i = BigDecimal("0")
    z = one
    while d.nonzero? && ((m = n - (y.exponent - d.exponent).abs) > 0)
      m = BigDecimal.double_fig if m < BigDecimal.double_fig
      sign = -sign
      x1  = x2.mult(x1,n)
      i  += two
      z  *= (i-one) * i
      d   = sign * x1.div(z,m)
      y  += d
    end
    y < -1 ? BigDecimal("-1") : y > 1 ? BigDecimal("1") : y
  end

  # Calculate a relative precision value from a block that calculates with a fixed precision.
  private def _ensure_relative_precision(prec)
    fixed_point_precision = prec + BigDecimal.double_fig
    loop do
      value = yield fixed_point_precision
      return value if !value.zero? && prec - value.exponent <= fixed_point_precision

      if value.zero? || fixed_point_precision < -value.exponent
        # Multiply precision by 3/2 if the calculated precision is not enough for estimating required precision
        fixed_point_precision = fixed_point_precision * 3 / 2
      else
        fixed_point_precision = prec - value.exponent + BigDecimal.double_fig
      end
    end
  end

  # call-seq:
  #   tan(decimal, numeric) -> BigDecimal
  #
  # Computes the tangent of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is Infinity or NaN, returns NaN.
  #
  #   BigMath.tan(BigMath.PI(16) / 3, 16).to_s
  #   #=> "0.17320508075688772935274463415059e1"
  #
  def tan(x, prec)
    return BigDecimal(0) if x.zero?

    # BigMath calculates sin with relative precision only when x.abs is small
    sin = x.abs < 3 ? sin(x, prec) : _ensure_relative_precision(prec) {|p| sin(x, p) }

    cos = _ensure_relative_precision(prec) {|p| cos(x, p) }
    sin.div(cos, prec + BigDecimal.double_fig)
  end

  # call-seq:
  #   asin(decimal, numeric) -> BigDecimal
  #
  # Computes the arcsine of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.asin(BigDecimal('0.5'), 16).to_s
  #   #=> "0.52359877559829887307710723054659e0"
  #
  def asin(x, prec)
    raise ArgumentError, "Zero or negative precision for asin" if prec <= 0
    raise Math::DomainError, "Out of domain argument for asin" if x < -1 || x > 1
    return BigDecimal::NAN if x.nan?
    prec2 = prec + BigDecimal.double_fig
    cos = (1 - x**2).sqrt(prec2)
    if cos.zero?
      pi = PI(prec)
      x > 0 ? pi / 2 : -pi / 2
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
  #   BigMath.acos(BigDecimal('0.5'), 16).to_s
  #   #=> "0.10471975511965977461542144610932e1"
  #
  def acos(x, prec)
    raise ArgumentError, "Zero or negative precision for acos" if prec <= 0
    raise Math::DomainError, "Out of domain argument for acos" if x < -1 || x > 1

    return PI(prec) / 2 - asin(x, prec) if x < 0
    return PI(prec) / 2 if x.zero?
    return BigDecimal::NAN if x.nan?

    prec2 = prec + BigDecimal.double_fig
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
  #   BigMath.atan(BigDecimal('-1'), 16).to_s
  #   #=> "-0.785398163397448309615660845819878471907514682065e0"
  #
  def atan(x, prec)
    raise ArgumentError, "Zero or negative precision for atan" if prec <= 0
    return BigDecimal("NaN") if x.nan?
    pi = PI(prec)
    x = -x if neg = x < 0
    return pi.div(neg ? -2 : 2, prec) if x.infinite?
    return pi / (neg ? -4 : 4) if x.round(prec) == 1
    n = prec + BigDecimal.double_fig
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
    y.mult(1, n)
  end

  # call-seq:
  #   atan2(decimal, decimal, numeric) -> BigDecimal
  #
  # Computes the arctangent of y and x to the specified number of digits of
  # precision, +numeric+.
  #
  #   BigMath.atan2(BigDecimal('-1'), BigDecimal('1'), 16).to_s
  #   #=> "-0.785398163397448309615660845819878471907514682065e0"
  #
  def atan2(y, x, prec)
    if x.infinite? || y.infinite?
      one = BigDecimal(1)
      zero = BigDecimal(0)
      x = x.infinite? ? (x > 0 ? one : -one) : zero
      y = y.infinite? ? (y > 0 ? one : -one) : y.sign * zero
    end

    return x.sign >= 0 ? BigDecimal(0) : y.sign * PI(prec) if y.zero?

    y = -y if neg = y < 0
    xlarge = y.abs < x.abs
    divprec = prec + BigDecimal.double_fig
    if x > 0
      v = xlarge ? atan(y.div(x, divprec), prec) : PI(prec) / 2 - atan(x.div(y, divprec), prec)
    else
      v = xlarge ? PI(prec) - atan(-y.div(x, divprec), prec) : PI(prec) / 2 + atan(x.div(-y, divprec), prec)
    end
    neg ? -v : v
  end

  # call-seq:
  #   sinh(decimal, numeric) -> BigDecimal
  #
  # Computes the hyperbolic sine of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.sinh(BigDecimal('1'), 16).to_s
  #   #=> "0.11752011936438014568823818505956e1"
  #
  def sinh(x, prec)
    raise ArgumentError, "Zero or negative precision for sinh" if prec <= 0
    return BigDecimal::NAN if x.nan?
    return x if x.infinite?

    prec += BigDecimal.double_fig
    prec -= x.exponent if x.exponent < 0
    e = BigMath.exp(x, prec)
    (e - BigDecimal(1).div(e, prec)).div(2, prec)
  end

  # call-seq:
  #   cosh(decimal, numeric) -> BigDecimal
  #
  # Computes the hyperbolic cosine of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.cosh(BigDecimal('1'), 16).to_s
  #   #=> "0.15430806348152437784779056207571e1"
  #
  def cosh(x, prec)
    raise ArgumentError, "Zero or negative precision for cosh" if prec <= 0
    return BigDecimal::NAN if x.nan?
    return BigDecimal::INFINITY if x.infinite?

    prec += BigDecimal.double_fig
    e = BigMath.exp(x, prec)
    (e + BigDecimal(1).div(e, prec)).div(2, prec)
  end

  # call-seq:
  #   tanh(decimal, numeric) -> BigDecimal
  #
  # Computes the hyperbolic tangent of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.tanh(BigDecimal('1'), 16).to_s
  #   #=> "0.7615941559557648881194582826048e0"
  #
  def tanh(x, prec)
    raise ArgumentError, "Zero or negative precision for tanh" if prec <= 0
    return BigDecimal::NAN if x.nan?
    return BigDecimal(x.infinite?) if x.infinite?

    prec += BigDecimal.double_fig
    prec2 = prec + [-x.exponent, 0].max
    e = BigMath.exp(x, prec2)
    einv = BigDecimal(1).div(e, prec2)
    (e - einv).div(e + einv, prec)
  end

  # call-seq:
  #   PI(numeric) -> BigDecimal
  #
  # Computes the value of pi to the specified number of digits of precision,
  # +numeric+.
  #
  #   BigMath.PI(10).to_s
  #   #=> "0.3141592653589793238462643388813853786957412e1"
  #
  def PI(prec)
    raise ArgumentError, "Zero or negative precision for PI" if prec <= 0
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
    pi
  end

  # call-seq:
  #   E(numeric) -> BigDecimal
  #
  # Computes e (the base of natural logarithms) to the specified number of
  # digits of precision, +numeric+.
  #
  #   BigMath.E(10).to_s
  #   #=> "0.271828182845904523536028752390026306410273e1"
  #
  def E(prec)
    raise ArgumentError, "Zero or negative precision for E" if prec <= 0
    BigMath.exp(1, prec)
  end
end
