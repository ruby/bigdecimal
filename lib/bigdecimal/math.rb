# frozen_string_literal: false
require 'bigdecimal'

#
#--
# Contents:
#   sqrt(x, prec)
#   sin (x, prec)
#   cos (x, prec)
#   tan (x, prec)
#   atan(x, prec)
#   PI  (prec)
#   E   (prec) == exp(1.0,prec)
#
# where:
#   x    ... BigDecimal number to be computed.
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
    BigDecimal::Internal.validate_prec(prec, :sqrt)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :sqrt)
    x.sqrt(prec)
  end


  # Returns [sign, reduced_x] where reduced_x is in -pi/2..pi/2
  # and satisfies sin(x) = sign * sin(reduced_x)
  # If add_half_pi is true, adds pi/2 to x before reduction.
  # Precision of pi is adjusted to ensure reduced_x has the required precision.
  private def _sin_periodic_reduction(x, prec, add_half_pi: false)
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
    BigDecimal::Internal.validate_prec(prec, :sin)
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
    y *= sign
    y < -1 ? BigDecimal("-1") : y > 1 ? BigDecimal("1") : y
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
    BigDecimal::Internal.validate_prec(prec, :cos)
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
  #   BigMath.tan(BigMath.PI(4) / 4, 4).to_s
  #   #=> "0.99999999999999999999419869652481995799388629632650769e0"
  #
  def tan(x, prec)
    BigDecimal::Internal.validate_prec(prec, :tan)
    sin(x, prec) / cos(x, prec)
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
    BigDecimal::Internal.validate_prec(prec, :atan)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :atan)
    return BigDecimal::Internal.nan_computation_result if x.nan?
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
    y
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
    BigDecimal::Internal.validate_prec(prec, :PI)
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
    BigDecimal::Internal.validate_prec(prec, :E)
    BigMath.exp(1, prec)
  end
end
