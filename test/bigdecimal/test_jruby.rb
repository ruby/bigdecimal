# frozen_string_literal: false
require_relative 'helper'
require 'bigdecimal/math'

class TestJRuby < Test::Unit::TestCase
  # JRuby uses its own native BigDecimal implementation
  # but uses the same BigMath module as CRuby.
  # These are test to ensure BigMath works correctly with JRuby's BigDecimal.
  # Also run on CRuby to ensure compatibility.

  N = 20

  def test_decimal_shift_polyfill
    assert_equal(BigDecimal('123.45e2'), BigDecimal('123.45')._decimal_shift(2))
    assert_equal(BigDecimal('123.45e-2'), BigDecimal('123.45')._decimal_shift(-2))
    assert_equal(BigDecimal('123.45e10000'), BigDecimal('123.45')._decimal_shift(10000))
    assert_equal(BigDecimal('123.45e-10000'), BigDecimal('123.45')._decimal_shift(-10000))
  end

  def test_sqrt
    sqrt2 = BigDecimal(2).sqrt(N)
    assert_in_delta(Math.sqrt(2), sqrt2)
    assert_in_delta(2, sqrt2 * sqrt2)
  end

  def test_exp
    assert_in_delta(Math.exp(2), BigMath.exp(BigDecimal(2), N))
    assert_in_delta(Math.exp(2), BigMath.exp(2, N))
    assert_in_delta(Math.exp(2.5), BigMath.exp(2.5, N))
    assert_in_delta(Math.exp(2.5), BigMath.exp(2.5r, N))
  end

  def test_log
    assert_in_delta(Math.log(2), BigMath.log(BigDecimal(2), N))
    assert_in_delta(Math.log(2), BigMath.log(2, N))
    assert_in_delta(Math.log(2.5), BigMath.log(2.5, N))
    assert_in_delta(Math.log(2.5), BigMath.log(2.5r, N))
  end

  def test_power
    x = BigDecimal(2)
    expected = 2 ** 2.5
    assert_in_delta(expected, x ** BigDecimal('2.5'))
    assert_in_delta(expected, x.sqrt(N) ** 5)
    assert_in_delta(expected, x ** 2.5)
    assert_in_delta(expected, x ** 2.5r)
    assert_in_delta(expected, x.power(BigDecimal('2.5'), N))
    assert_in_delta(expected, x.power(2.5, N))
    assert_in_delta(expected, x.sqrt(N).power(5, N))
    assert_in_delta(expected, x.power(2.5r, N))
  end

  def test_bigmath
    assert_in_delta(Math.sqrt(2), BigMath.sqrt(BigDecimal(2), N))
    assert_in_delta(Math.cbrt(2), BigMath.cbrt(BigDecimal(2), N))
    assert_in_delta(Math.hypot(2, 3), BigMath.hypot(BigDecimal(2), BigDecimal(3), N))
    assert_in_delta(Math.sin(1), BigMath.sin(BigDecimal(1), N))
    assert_in_delta(Math.cos(1), BigMath.cos(BigDecimal(1), N))
    assert_in_delta(Math.tan(1), BigMath.tan(BigDecimal(1), N))
    assert_in_delta(Math.asin(0.5), BigMath.asin(BigDecimal('0.5'), N))
    assert_in_delta(Math.acos(0.5), BigMath.acos(BigDecimal('0.5'), N))
    assert_in_delta(Math.atan(1), BigMath.atan(BigDecimal(1), N))
    assert_in_delta(Math.atan2(1, 2), BigMath.atan2(BigDecimal(1), BigDecimal(2), N))
    assert_in_delta(Math.sinh(1), BigMath.sinh(BigDecimal(1), N))
    assert_in_delta(Math.cosh(1), BigMath.cosh(BigDecimal(1), N))
    assert_in_delta(Math.tanh(1), BigMath.tanh(BigDecimal(1), N))
    assert_in_delta(Math.asinh(1), BigMath.asinh(BigDecimal(1), N))
    assert_in_delta(Math.acosh(2), BigMath.acosh(BigDecimal(2), N))
    assert_in_delta(Math.atanh(0.5), BigMath.atanh(BigDecimal('0.5'), N))
    assert_in_delta(Math.log2(3), BigMath.log2(BigDecimal(3), N))
    assert_in_delta(Math.log10(3), BigMath.log10(BigDecimal(3), N))
    assert_in_delta(Math.log1p(0.1), BigMath.log1p(BigDecimal('0.1'), N)) if defined? Math.log1p
    assert_in_delta(Math.expm1(0.1), BigMath.expm1(BigDecimal('0.1'), N)) if defined? Math.expm1
    assert_in_delta(Math.erf(1), BigMath.erf(BigDecimal(1), N))
    assert_in_delta(Math.erfc(10), BigMath.erfc(BigDecimal(10), N))
    assert_in_delta(Math.gamma(0.5), BigMath.gamma(BigDecimal('0.5'), N))
    assert_in_delta(Math.lgamma(0.5).first, BigMath.lgamma(BigDecimal('0.5'), N).first)
    assert_equal([BigDecimal('0.123'), 4], BigMath.frexp(BigDecimal('0.123e4')))
    assert_equal(BigDecimal('12.3e4'), BigMath.ldexp(BigDecimal('12.3'), 4))
    assert_in_delta(Math::PI, BigMath.PI(N))
    assert_in_delta(Math::E, BigMath.E(N))
  end
end
