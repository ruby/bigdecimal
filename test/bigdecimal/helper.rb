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

  # Asserts that the calculation of the given block converges to some value
  # with precision specified by block parameter.

  def assert_fixed_point_precision(&block)
    _assert_precision(:fixed_point, &block)
  end

  def assert_relative_precision(&block)
    _assert_precision(:relative, &block)
  end

  def _assert_precision(mode)
    expected = yield(200)
    [50, 100, 150].each do |n|
      value = yield(n)
      if mode == :fixed_point
        precision = -(value - expected).exponent
      elsif mode == :relative
        precision = -(value.div(expected, expected.precision) - 1).exponent
      else
        raise ArgumentError, "Unknown mode: #{mode}"
      end
      assert(value != expected, "Unable to estimate precision for exact value")
      assert(precision >= n, "Precision is not enough: #{precision} < #{n}")
    end
  end
end
