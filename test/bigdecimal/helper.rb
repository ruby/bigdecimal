# frozen_string_literal: false
require "test/unit"
require "bigdecimal"
require 'rbconfig/sizeof'

module TestBigDecimalBase
  if RbConfig::SIZEOF.key?("int64_t")
    SIZEOF_DECDIG = RbConfig::SIZEOF["int32_t"]
    BASE = 1_000_000_000
    BASE_FIG = 9
  else
    SIZEOF_DECDIG = RbConfig::SIZEOF["int16_t"]
    BASE = 1000
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

  # Asserts that the calculation of the given block converges to some value
  # with a precision of at least n digits.

  def assert_fixed_point_precision(n = 100)
    value = yield(n)
    expected = yield(2 * n)
    precision = -(value - expected).exponent
    assert(value != expected, "Unable to estimate precision for exact value")
    assert(precision >= n, "Precision is not enough: #{precision} < #{n}")
  end

  def assert_relative_precision(n = 100)
    value = yield(n)
    expected = yield(2 * n)
    precision = -(value.div(expected, 2 * n) - 1).exponent
    assert(value != expected, "Unable to estimate precision for exact value")
    assert(precision >= n, "Precision is not enough: #{precision} < #{n}")
  end
end
