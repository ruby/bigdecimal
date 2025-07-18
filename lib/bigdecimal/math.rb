# frozen_string_literal: false
require 'bigdecimal'

#
#--
# Contents:
#   sqrt(x, prec)
#   sin (x, prec)
#   cos (x, prec)
#   atan(x, prec)
#   erf (x, prec)
#   erfc(x, prec)
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
    x.sqrt(prec)
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

  # call-seq:
  #   erf(decimal, numeric) -> BigDecimal
  #
  # Computes the error function of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.erf(BigDecimal('1'), 16).to_s
  #   #=> "0.84270079294971486934122063508259e0"
  #
  def erf(x, prec)
    raise ArgumentError, "Zero or negative precision for erf" if prec <= 0
    return BigDecimal("NaN") if x.nan?
    return BigDecimal(0) if x == 0
    # erf(x) = (2 / sqrt(pi)) * exp(-x**2) * sum { 4**k * k! * x**(2k + 1) / (2k + 1)! }
    # Controlling precision of this series is easier than normal erf taylor series.
    prec += BigDecimal.double_fig
    x2 = x.mult(x, prec)

    log10 = 2.302585092994046
    return BigDecimal(x > 0 ? 1 : -1) if x2 > prec * log10

    a = BigDecimal(2).div(sqrt(PI(prec), prec), prec).mult(BigMath.exp(-x2, prec), prec)
    b = x
    d = x
    1.step do |k|
      d = d.mult(2, prec).div(2 * k + 1, prec).mult(x2, prec)
      b = b.add(d, prec)
      if d.exponent < b.exponent - prec
        break
      end
    end
    v = a.mult(b, prec)
    v > 1 ? BigDecimal(1) : v
  end

  # call-seq:
  #   erfc(decimal, numeric) -> BigDecimal
  #
  # Computes the complementary error function of +decimal+ to the specified number of digits of
  # precision, +numeric+.
  #
  # If +decimal+ is NaN, returns NaN.
  #
  #   BigMath.erfc(BigDecimal('10'), 16).to_s
  #   #=> "0.20884875837625447570007862949578e-44"
  #
  def erfc(x, prec)
    raise ArgumentError, "Zero or negative precision for erfc" if prec <= 0
    return BigDecimal("NaN") if x.nan?
    return BigDecimal(1).sub(erf(x, prec), prec + BigDecimal.double_fig) if x < 0

    if x >= 8
      # Faster asymptotic expansion can be used if x is large enough
      y = _erfc_asymptotic(x, prec)
      return y if y
    end

    prec += BigDecimal.double_fig

    # erfc(x) = 1 - erf(x) < exp(-x**2)/x/sqrt(pi)
    # Precision of erf(x) needs about log10(exp(-x**2)) extra digits
    log10 = 2.302585092994046
    high_prec = prec + (x**2 / log10).ceil
    BigDecimal(1).sub(erf(x, high_prec), prec)
  end

  private def _erfc_asymptotic(x, prec)
    # Let f(x) = erfc(x)*sqrt(pi)*exp(x**2)/2
    # f(x) satisfies the following differential equation:
    # 2*x*f(x) = f'(x) + 1
    # From the above equation, we can derive the following asymptotic expansion:
    # f(x) = sum { (-1)**k * (2*k)! / 4***k / k! / x**(2*k)) } / x

    # This asymptotic expansion does not converge.
    # But if there is a k that satisfies (2*k)! / 4***k / k! / x**(2*k) < 10**(-prec),
    # It is enough to calculate erfc within the given precision.
    # (2*k)! / 4**k / k! can be approximated as sqrt(2) * (k/e)**k by using Stirling's approximation.
    prec += BigDecimal.double_fig
    xf = x.to_f
    log10xf = Math.log10(xf)
    kmax = 1
    until kmax * Math.log10(kmax / Math::E) + 1 - 2 * kmax * log10xf < -prec
      kmax += 1
      return if xf * xf < kmax # unable to calculate with the given precision
    end

    sum = BigDecimal(1)
    xinv = BigDecimal(1).div(x, prec)
    xinv2 = xinv.mult(xinv, prec)
    d = BigDecimal(1)
    (1..kmax).each do |k|
      d = d.mult(xinv2, prec).mult(1 - 2 * k, prec).div(2, prec)
      sum = sum.add(d, prec)
    end
    expx2 = BigMath.exp(x.mult(x, prec), prec)

    # Workaround for https://github.com/ruby/bigdecimal/issues/345
    expx2 = BigDecimal(expx2) unless expx2.is_a?(BigDecimal)

    sum.div(expx2.mult(PI(prec).sqrt(prec), prec), prec).mult(xinv, prec)
  end
end
