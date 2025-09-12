# frozen_string_literal: false
require "test/unit"
require "bigdecimal"
require 'rbconfig/sizeof'

module TestBigDecimalBase
  BASE = BigDecimal::BASE
  case BASE
  when 1000000000
    SIZEOF_DECDIG = RbConfig::SIZEOF["int32_t"]
    BASE_FIG = 9
  when 10000
    SIZEOF_DECDIG = RbConfig::SIZEOF["int16_t"]
    BASE_FIG = 4
  end

  def setup
    @mode = BigDecimal.mode(BigDecimal::EXCEPTION_ALL)
    BigDecimal.mode(BigDecimal::EXCEPTION_ALL, true)
    BigDecimal.mode(BigDecimal::EXCEPTION_UNDERFLOW, true)
    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, true)
    BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_HALF_UP)
    BigDecimal.limit(0)
  end

  def teardown
    [BigDecimal::EXCEPTION_INFINITY, BigDecimal::EXCEPTION_NaN,
     BigDecimal::EXCEPTION_UNDERFLOW, BigDecimal::EXCEPTION_OVERFLOW].each do |mode|
      BigDecimal.mode(mode, !(@mode & mode).zero?)
    end
  end

  def under_gc_stress
    stress, GC.stress = GC.stress, true
    yield
  ensure
    GC.stress = stress
  end

  # Asserts that +actual+ is calculated with exactly the given +precision+.
  # No extra digits are allowed. Only the last digit may differ at most by one.
  def assert_in_exact_precision(expected, actual, precision)
    expected = BigDecimal(expected)
    delta = BigDecimal(1)._decimal_shift(expected.exponent - precision)
    assert actual.n_significant_digits <= precision, "Too many significant digits: #{actual.n_significant_digits} > #{precision}"
    assert_in_delta(expected.mult(1, precision), actual, delta)
  end

  # Asserts that the calculation of the given block converges to some value
  # with exactly the given +precision+.
  def assert_converge_in_precision(&block)
    expected = yield(200)
    [50, 100, 150].each do |n|
      value = yield(n)
      assert(value != expected, "Unable to estimate precision for exact value")
      assert_in_exact_precision(expected, value, n)
    end
  end
end
