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
      assert_equal(expected.mult(1, n), value)
    end
  end


  def assert_nan(x)
    assert(x.nan?, "Expected #{x.inspect} to be NaN")
  end

  def assert_positive_infinite(x)
    assert(x.infinite?, "Expected #{x.inspect} to be positive infinite")
    assert_operator(x, :>, 0)
  end

  def assert_negative_infinite(x)
    assert(x.infinite?, "Expected #{x.inspect} to be negative infinite")
    assert_operator(x, :<, 0)
  end

  def assert_infinite_calculation(positive:)
    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
      positive ? assert_positive_infinite(yield) : assert_negative_infinite(yield)
      BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, true)
      assert_raise_with_message(FloatDomainError, /Infinity/) { yield }
    end
  end

  def assert_positive_infinite_calculation(&block)
    assert_infinite_calculation(positive: true, &block)
  end

  def assert_negative_infinite_calculation(&block)
    assert_infinite_calculation(positive: false, &block)
  end

  def assert_nan_calculation(&block)
    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
      assert_nan(yield)
      BigDecimal.mode(BigDecimal::EXCEPTION_NaN, true)
      assert_raise_with_message(FloatDomainError, /NaN/) { yield }
    end
  end

  def assert_positive_zero(x)
    assert_equal(BigDecimal::SIGN_POSITIVE_ZERO, x.sign,
                 "Expected #{x.inspect} to be positive zero")
  end

  def assert_negative_zero(x)
    assert_equal(BigDecimal::SIGN_NEGATIVE_ZERO, x.sign,
                 "Expected #{x.inspect} to be negative zero")
  end
end
