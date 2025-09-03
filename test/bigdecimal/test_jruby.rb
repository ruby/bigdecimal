# frozen_string_literal: false
require_relative 'helper'
require 'bigdecimal/math'

class TestJRuby < Test::Unit::TestCase
  # JRuby uses its own native BigDecimal implementation
  # but uses the same BigMath module as CRuby.
  # These are test to ensure BigMath works correctly with JRuby's BigDecimal.
  # Also run on CRuby to ensure compatibility.

  N = 20

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
    # assert_in_delta(expected, x ** 2.5)
    assert_in_delta(expected, x ** 2.5r)
    assert_in_delta(expected, x.power(BigDecimal('2.5'), N))
    # assert_in_delta(expected, x.power(2.5, N))
    assert_in_delta(expected, x.sqrt(N).power(5, N))
    assert_in_delta(expected, x.power(2.5r, N))
  end

  def test_bigmath
    assert_in_delta(Math.sqrt(2), BigMath.sqrt(BigDecimal(2), N))
    assert_in_delta(Math.sin(1), BigMath.sin(BigDecimal(1), N))
    assert_in_delta(Math.cos(1), BigMath.cos(BigDecimal(1), N))
    assert_in_delta(Math.atan(1), BigMath.atan(BigDecimal(1), N))
    assert_in_delta(Math::PI, BigMath.PI(N))
    assert_in_delta(Math::E, BigMath.E(N))
  end
end
