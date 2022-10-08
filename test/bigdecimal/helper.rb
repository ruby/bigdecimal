# frozen_string_literal: false
require "test/unit"
require "bigdecimal"
require "rbconfig/sizeof"

module TestBigDecimalBase
  ROUNDING_MODE_MAP = [
    [ BigDecimal::ROUND_UP,        :up],
    [ BigDecimal::ROUND_DOWN,      :down],
    [ BigDecimal::ROUND_DOWN,      :truncate],
    [ BigDecimal::ROUND_HALF_UP,   :half_up],
    [ BigDecimal::ROUND_HALF_UP,   :default],
    [ BigDecimal::ROUND_HALF_DOWN, :half_down],
    [ BigDecimal::ROUND_HALF_EVEN, :half_even],
    [ BigDecimal::ROUND_HALF_EVEN, :banker],
    [ BigDecimal::ROUND_CEILING,   :ceiling],
    [ BigDecimal::ROUND_CEILING,   :ceil],
    [ BigDecimal::ROUND_FLOOR,     :floor],
  ]

  if RbConfig::SIZEOF.key?("int64_t")
    SIZEOF_DECDIG = RbConfig::SIZEOF["int32_t"]
    BASE = 1_000_000_000
    BASE_FIG = 9
  else
    SIZEOF_DECDIG = RbConfig::SIZEOF["int16_t"]
    BASE = 1000
    BASE_FIG = 4
  end

  if defined? RbConfig::LIMITS
    LIMITS = RbConfig::LIMITS
  else
    require "fiddle"
    LONG_MAX = (1 << (Fiddle::SIZEOF_LONG*8 - 1)) - 1
    LONG_MIN = [LONG_MAX + 1].pack("L!").unpack("l!")[0]
    LLONG_MAX = (1 << (Fiddle::SIZEOF_LONG_LONG*8 - 1)) - 1
    LLONG_MIN = [LLONG_MAX + 1].pack("Q!").unpack("q!")[0]
    ULLONG_MAX = (1 << Fiddle::SIZEOF_LONG_LONG*8) - 1
    LIMITS = {
      "LLONG_MIN" => LLONG_MIN,
      "ULLONG_MAX" => ULLONG_MAX,
      "FIXNUM_MIN" => LONG_MIN / 2,
      "FIXNUM_MAX" => LONG_MAX / 2,
      "INT64_MIN"  => -9223372036854775808,
      "INT64_MAX"  => 9223372036854775807,
      "UINT64_MAX" => 18446744073709551615,
    }.freeze
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
end
