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
    return -erf(-x, prec) if x < 0

    prec += BigDecimal.double_fig

    if x > 8 && (erfc1 = _erfc_asymptotic(x.abs, 1))
      erfc2 = _erfc_asymptotic(x.abs, [prec + erfc1.exponent, 1].max)
      return BigDecimal(1).sub(erfc2, prec) if erfc2
    end

    base = BigDecimal::BASE ** 2
    x_smallprec = (x * base).fix / base
    # Taylor series of x with small precision is fast
    erf1 = _erf_taylor(x_smallprec, BigDecimal(0), BigDecimal(0), prec)
    # Taylor series converges quickly for small x
    v = _erf_taylor(x - x_smallprec, x_smallprec, erf1, prec)
    [BigDecimal(1), v].min
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


  private def _erf_taylor(x, a, erf_a, prec)
    # Let f(x) = erf(x+a)*exp((x+a)**2)*sqrt(pi)/2
    #          = c0 + c1*x + c2*x**2 + c3*x**3 + c4*x**4 + ...
    # f'(x) = 1+2*(x+a)*f(x)
    # f'(x) = c1 + 2*c2*x + 3*c3*x**2 + 4*c4*x**3 + 5*c5*x**4 + ...
    #       = 1+2*(x+a)*(c0 + c1*x + c2*x**2 + c3*x**3 + c4*x**4 + ...)
    # therefore,
    # c0 = f(0)
    # c1 = 2 * a * c0 + 1
    # c2 = (2 * c0 + 2 * a * c1) / 2
    # c3 = (2 * c1 + 2 * a * c2) / 3
    # c4 = (2 * c2 + 2 * a * c3) / 4

    return erf_a if x.zero?

    scale = BigDecimal(2).div(sqrt(PI(prec), prec), prec)
    c_prev = erf_a.div(scale.mult(BigMath.exp(-a*a, prec), prec), prec)
    c_next = (2 * a * c_prev).add(1, prec).mult(x, prec)
    v = c_prev.add(c_next, prec)

    2.step do |k|
      c = (c_prev.mult(x, prec) + a * c_next).mult(2, prec).mult(x, prec).div(k, prec)
      v = v.add(c, prec)
      c_prev, c_next = c_next, c
      break if [c_prev, c_next].all? { |c| c.zero?  || (c.exponent < v.exponent - prec) }
    end
    v = v.mult(scale.mult(BigMath.exp(-(x + a).mult(x + a, prec), prec), prec), prec)
    v > 1 ? BigDecimal(1) : v
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
      return if xf * xf < kmax # Unable to calculate with the given precision
    end

    sum = BigDecimal(1)
    x2 = x.mult(x, prec)
    d = BigDecimal(1)
    (1..kmax).each do |k|
      d = d.div(x2, prec).mult(1 - 2 * k, prec).div(2, prec)
      sum = sum.add(d, prec)
    end
    expx2 = BigMath.exp(x.mult(x, prec), prec)
    sum.div(expx2.mult(PI(prec).sqrt(prec), prec), prec).div(x, prec)
  end
end
