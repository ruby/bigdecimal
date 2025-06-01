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
    BigDecimal::Internal.validate_prec(prec, :sqrt)
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
  #   BigMath.tan(BigMath.PI(24) / 4, 32).to_s
  #   #=> "0.99999999999999999999999830836025e0"
  #
  def tan(x, prec)
    BigDecimal::Internal.validate_prec(prec, :tan)
    sin(x, prec + BigDecimal.double_fig).div(cos(x, prec + BigDecimal.double_fig), prec)
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
    BigDecimal::Internal.validate_prec(prec, :atan)
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
  #   PI(numeric) -> BigDecimal
  #
  # Computes the value of pi to the specified number of digits of precision,
  # +numeric+.
  #
  #   BigMath.PI(32).to_s
  #   #=> "0.31415926535897932384626433832795e1"
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
    BigDecimal::Internal.validate_prec(prec, :E)
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
  #   BigMath.erf(BigDecimal('1'), 32).to_s
  #   #=> "0.84270079294971486934122063508261e0"
  #
  def erf(x, prec)
    BigDecimal::Internal.validate_prec(prec, :erf)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :erf)
    return BigDecimal::Internal.nan_computation_result if x.nan?
    return BigDecimal(x.infinite?) if x.infinite?
    return BigDecimal(0) if x == 0
    return -erf(-x, prec) if x < 0

    if x > 8 && (erfc1 = _erfc_asymptotic(x, 1))
      erfc2 = _erfc_asymptotic(x, [prec + erfc1.exponent, 1].max)
      return BigDecimal(1).sub(erfc2, prec) if erfc2
    end

    prec2 = prec + BigDecimal.double_fig
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
    BigDecimal::Internal.validate_prec(prec, :erfc)
    x = BigDecimal::Internal.coerce_to_bigdecimal(x, prec, :erfc)
    return BigDecimal::Internal.nan_computation_result if x.nan?
    return BigDecimal(1 - x.infinite?) if x.infinite?
    return BigDecimal(1).sub(erf(x, prec), prec) if x < 0

    if x >= 8
      y = _erfc_asymptotic(x, prec)
      return y.mult(1, prec) if y
    end

    # erfc(x) = 1 - erf(x) < exp(-x**2)/x/sqrt(pi)
    # Precision of erf(x) needs about log10(exp(-x**2)) extra digits
    log10 = 2.302585092994046
    high_prec = prec + BigDecimal.double_fig + (x**2 / log10).ceil
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
    # f(x) = (0..kmax).sum { (-1)**k * (2*k)! / 4**k / k! / x**(2*k)) } / x

    # This asymptotic expansion does not converge.
    # But if there is a k that satisfies (2*k)! / 4**k / k! / x**(2*k) < 10**(-prec),
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
