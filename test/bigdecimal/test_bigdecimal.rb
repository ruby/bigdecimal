# frozen_string_literal: false
require_relative "helper"
require 'bigdecimal/math'

class TestBigDecimal < Test::Unit::TestCase
  include TestBigDecimalBase

  if defined? RbConfig::LIMITS
    LIMITS = RbConfig::LIMITS
  else
    require 'fiddle'
    INTPTR_MAX = (1 << (Fiddle::SIZEOF_INTPTR_T*8 - 1)) - 1
    INTPTR_MIN = [INTPTR_MAX + 1].pack("L!").unpack("l!")[0]
    LONG_MAX = (1 << (Fiddle::SIZEOF_LONG*8 - 1)) - 1
    LONG_MIN = [LONG_MAX + 1].pack("L!").unpack("l!")[0]
    LLONG_MAX = (1 << (Fiddle::SIZEOF_LONG_LONG*8 - 1)) - 1
    LLONG_MIN = [LLONG_MAX + 1].pack("Q!").unpack("q!")[0]
    ULLONG_MAX = (1 << Fiddle::SIZEOF_LONG_LONG*8) - 1
    LIMITS = {
      "INTPTR_MAX" => INTPTR_MAX,
      "INTPTR_MIN" => INTPTR_MIN,
      "LLONG_MIN" => LLONG_MIN,
      "ULLONG_MAX" => ULLONG_MAX,
      "FIXNUM_MIN" => LONG_MIN / 2,
      "FIXNUM_MAX" => LONG_MAX / 2,
      "INT64_MIN"  => -9223372036854775808,
      "INT64_MAX"  => 9223372036854775807,
      "UINT64_MAX" => 18446744073709551615,
    }.freeze
  end

  EXPONENT_MAX = LIMITS['INTPTR_MAX'] / BASE_FIG * BASE_FIG
  EXPONENT_MIN = (LIMITS['INTPTR_MIN'] - 2) / BASE_FIG * BASE_FIG + BASE_FIG + 1

  NEGATIVE_INFINITY = -BigDecimal::INFINITY

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

  def test_not_equal
    assert_not_equal BigDecimal("1"), BigDecimal("2")
  end

  def test_BigDecimal
    assert_equal(1, BigDecimal("1"))
    assert_equal(1, BigDecimal("1", 1))
    assert_equal(1, BigDecimal(" 1 "))
    assert_equal(111, BigDecimal("1_1_1_"))
    assert_equal(10**(-1), BigDecimal("1E-1"), '#4825')
    assert_equal(1234, BigDecimal(" \t\n\r \r1234 \t\n\r \r"))
    assert_equal(0.0, BigDecimal("0."))
    assert_equal(0.0E-9, BigDecimal("0.E-9"))

    assert_raise(ArgumentError) { BigDecimal("1", -1) }
    assert_raise_with_message(ArgumentError, /"1__1_1"/) { BigDecimal("1__1_1") }
    assert_raise_with_message(ArgumentError, /"_1_1_1"/) { BigDecimal("_1_1_1") }
    assert(BigDecimal("0.1E#{EXPONENT_MAX}").finite?)
    assert(BigDecimal("0.1E#{EXPONENT_MIN}").finite?)

    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
      BigDecimal.mode(BigDecimal::EXCEPTION_UNDERFLOW, false)
      BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
      assert_positive_infinite(BigDecimal("Infinity"))
      assert_positive_infinite(BigDecimal("0.1E#{EXPONENT_MAX + 1}"))
      assert_negative_infinite(BigDecimal("-0.1E#{EXPONENT_MAX + 1}"))
      assert_positive_infinite(BigDecimal("1E#{EXPONENT_MAX}"))
      assert_negative_infinite(BigDecimal("-1E#{EXPONENT_MAX}"))
      assert_positive_zero(BigDecimal("0E#{EXPONENT_MAX + 1}"))
      assert_negative_zero(BigDecimal("-0E#{EXPONENT_MAX + 1}"))
      assert_positive_zero(BigDecimal("0.1E#{EXPONENT_MIN - 1}"))
      assert_negative_zero(BigDecimal("-0.1E#{EXPONENT_MIN - 1}"))
      assert_positive_zero(BigDecimal("0.01E#{EXPONENT_MIN}"))
      assert_negative_zero(BigDecimal("-0.01E#{EXPONENT_MIN}"))
      assert_positive_infinite(BigDecimal(" \t\n\r \rInfinity \t\n\r \r"))
      assert_negative_infinite(BigDecimal("-Infinity"))
      assert_negative_infinite(BigDecimal(" \t\n\r \r-Infinity \t\n\r \r"))
      assert_nan(BigDecimal("NaN"))
      assert_nan(BigDecimal(" \t\n\r \rNaN \t\n\r \r"))
    end
  end

  def test_BigDecimal_ignore_digits
    assert_equal(1, BigDecimal(1, LIMITS["FIXNUM_MAX"]))
    assert_equal(1, BigDecimal('1', LIMITS["FIXNUM_MAX"]))
  end

  def test_BigDecimal_bug7522
    bd = BigDecimal("1.12", 1)
    assert_same(bd, BigDecimal(bd))
    assert_same(bd, BigDecimal(bd, exception: false))
    assert_not_same(bd, BigDecimal(bd, 1))
    assert_not_same(bd, BigDecimal(bd, 1, exception: false))
  end

  def test_BigDecimal_issue_192
    # https://github.com/ruby/bigdecimal/issues/192
    # https://github.com/rails/rails/pull/42125
    if BASE_FIG == 9
      int = 1_000_000_000_12345_0000
      big = BigDecimal("0.100000000012345e19")
    else  # BASE_FIG == 4
      int = 1_0000_12_00
      big = BigDecimal("0.1000012e9")
    end
    assert_equal(BigDecimal(int), big, "[ruby/bigdecimal#192]")
  end

  def test_BigDecimal_with_invalid_string
    [
      '', '.', 'e1', 'd1', '.e', '.d', '1.e', '1.d', '.1e', '.1d',
      '2,30', '19,000.0', '-2,30', '-19,000.0', '+2,30', '+19,000.0',
      '2.3,0', '19.000,0', '-2.3,0', '-19.000,0', '+2.3,0', '+19.000,0',
      '2.3.0', '19.000.0', '-2.3.0', '-19.000.0', '+2.3.0', '+19.000.0',
      'invlaid value', '123 xyz'
    ].each do |invalid_string|
      assert_raise_with_message(ArgumentError, %Q[invalid value for BigDecimal(): "#{invalid_string}"]) do
        BigDecimal(invalid_string)
      end
    end

    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
      BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
      assert_raise_with_message(ArgumentError, /"Infinity_"/) { BigDecimal("Infinity_") }
      assert_raise_with_message(ArgumentError, /"\+Infinity_"/) { BigDecimal("+Infinity_") }
      assert_raise_with_message(ArgumentError, /"-Infinity_"/) { BigDecimal("-Infinity_") }
      assert_raise_with_message(ArgumentError, /"NaN_"/) { BigDecimal("NaN_") }
    end
  end

  def test_BigDecimal_with_integer
    assert_equal(BigDecimal("0"), BigDecimal(0))
    assert_equal(BigDecimal("1"), BigDecimal(1))
    assert_equal(BigDecimal("-1"), BigDecimal(-1))
    assert_equal(BigDecimal((2**100).to_s), BigDecimal(2**100))
    assert_equal(BigDecimal((-2**100).to_s), BigDecimal(-2**100))

    assert_equal(BigDecimal(LIMITS["FIXNUM_MIN"].to_s), BigDecimal(LIMITS["FIXNUM_MIN"]))

    assert_equal(BigDecimal(LIMITS["FIXNUM_MAX"].to_s), BigDecimal(LIMITS["FIXNUM_MAX"]))

    assert_equal(BigDecimal(LIMITS["INT64_MIN"].to_s), BigDecimal(LIMITS["INT64_MIN"]))

    assert_equal(BigDecimal(LIMITS["INT64_MAX"].to_s), BigDecimal(LIMITS["INT64_MAX"]))

    assert_equal(BigDecimal(LIMITS["UINT64_MAX"].to_s), BigDecimal(LIMITS["UINT64_MAX"]))
  end

  def test_BigDecimal_with_rational
    assert_equal(BigDecimal("0.333333333333333333333"), BigDecimal(1.quo(3), 21))
    assert_equal(BigDecimal("-0.333333333333333333333"), BigDecimal(-1.quo(3), 21))
    assert_raise_with_message(ArgumentError, "can't omit precision for a Rational.") { BigDecimal(42.quo(7)) }
  end

  def test_BigDecimal_with_float
    assert_equal(BigDecimal("0.1235"), BigDecimal(0.1234567, 4))
    assert_equal(BigDecimal("-0.1235"), BigDecimal(-0.1234567, 4))
    assert_equal(BigDecimal("0.01"), BigDecimal(0.01, Float::DIG + 1))
    assert_nothing_raised { BigDecimal(4.2) }
    assert_equal(BigDecimal(4.2), BigDecimal('4.2'))
    assert_equal(BigDecimal("0.12345"), BigDecimal(0.12345, 0))
    assert_equal(BigDecimal("0.12345"), BigDecimal(0.12345))
    assert_raise(ArgumentError) { BigDecimal(0.1, Float::DIG + 2) }
    assert_nothing_raised { BigDecimal(0.1, Float::DIG + 1) }

    assert_same(BigDecimal(0.0), BigDecimal(0.0))
    assert_same(BigDecimal(-0.0), BigDecimal(-0.0))

    bug9214 = '[ruby-core:58858]'
    assert_equal(BigDecimal(-0.0).sign, -1, bug9214)

    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
      assert_nan(BigDecimal(Float::NAN))
      assert_same(BigDecimal(Float::NAN), BigDecimal(Float::NAN))
    end
    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
      assert_positive_infinite(BigDecimal(Float::INFINITY))
      assert_same(BigDecimal(Float::INFINITY), BigDecimal(Float::INFINITY))
      assert_negative_infinite(BigDecimal(-Float::INFINITY))
      assert_same(BigDecimal(-Float::INFINITY), BigDecimal(-Float::INFINITY))
    end
  end

  def test_BigDecimal_with_complex
    assert_equal(BigDecimal("1"), BigDecimal(Complex(1, 0)))
    assert_equal(BigDecimal("0.333333333333333333333"), BigDecimal(Complex(1.quo(3), 0), 21))
    assert_equal(BigDecimal("0.1235"), BigDecimal(Complex(0.1234567, 0), 4))

    assert_raise_with_message(ArgumentError, "Unable to make a BigDecimal from non-zero imaginary number") { BigDecimal(Complex(1, 1)) }
  end

  def test_BigDecimal_with_big_decimal
    assert_equal(BigDecimal(1), BigDecimal(BigDecimal(1)))
    assert_equal(BigDecimal('+0'), BigDecimal(BigDecimal('+0')))
    assert_equal(BigDecimal('-0'), BigDecimal(BigDecimal('-0')))
    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
      BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
      assert_positive_infinite(BigDecimal(BigDecimal('Infinity')))
      assert_negative_infinite(BigDecimal(BigDecimal('-Infinity')))
      assert_nan(BigDecimal(BigDecimal('NaN')))
    end
  end

  if RUBY_VERSION < '2.7'
    def test_BigDecimal_with_tainted_string
      Thread.new {
        $SAFE = 1
        BigDecimal('1'.taint)
      }.join
    ensure
      $SAFE = 0
    end
  end

  def test_BigDecimal_with_exception_keyword
    assert_raise(ArgumentError) {
      BigDecimal('.', exception: true)
    }
    assert_nothing_raised(ArgumentError) {
      assert_equal(nil, BigDecimal(".", exception: false))
    }
    assert_raise(ArgumentError) {
      BigDecimal("1", -1, exception: true)
    }
    assert_nothing_raised(ArgumentError) {
      assert_equal(nil, BigDecimal("1", -1, exception: false))
    }
    assert_raise(ArgumentError) {
      BigDecimal(42.quo(7), exception: true)
    }
    assert_nothing_raised(ArgumentError) {
      assert_equal(nil, BigDecimal(42.quo(7), exception: false))
    }
    assert_raise(ArgumentError) {
      BigDecimal(4.2, Float::DIG + 2, exception: true)
    }
    assert_nothing_raised(ArgumentError) {
      assert_equal(nil, BigDecimal(4.2, Float::DIG + 2, exception: false))
    }
    # TODO: support conversion from complex
    # assert_raise(RangeError) {
    #   BigDecimal(1i, exception: true)
    # }
    # assert_nothing_raised(RangeError) {
    #   assert_equal(nil, BigDecimal(1i, exception: false))
    # }
    assert_raise_with_message(TypeError, "can't convert nil into BigDecimal") {
      BigDecimal(nil, exception: true)
    }
    assert_raise_with_message(TypeError, "can't convert true into BigDecimal") {
      BigDecimal(true, exception: true)
    }
    assert_raise_with_message(TypeError, "can't convert false into BigDecimal") {
      BigDecimal(false, exception: true)
    }
    assert_raise_with_message(TypeError, "can't convert Object into BigDecimal") {
      BigDecimal(Object.new, exception: true)
    }
    assert_nothing_raised(TypeError) {
      assert_equal(nil, BigDecimal(nil, exception: false))
    }
    assert_nothing_raised(TypeError) {
      assert_equal(nil, BigDecimal(:test, exception: false))
    }
    assert_nothing_raised(TypeError) {
      assert_equal(nil, BigDecimal(Object.new, exception: false))
    }
    assert_nothing_raised(TypeError) {
      assert_equal(nil, BigDecimal(Object.new, exception: false))
    }
    # TODO: support to_d
    # assert_nothing_raised(TypeError) {
    #   o = Object.new
    #   def o.to_d; 3.14; end
    #   assert_equal(3.14, BigDecimal(o, exception: false))
    # }
    # assert_nothing_raised(RuntimeError) {
    #   o = Object.new
    #   def o.to_d; raise; end
    #   assert_equal(nil, BigDecimal(o, exception: false))
    # }
  end

  def test_s_ver
    assert_raise_with_message(NoMethodError, /undefined method [`']ver'/) { BigDecimal.ver }
  end

  def test_s_allocate
    if RUBY_ENGINE == "truffleruby"
      assert_raise_with_message(NoMethodError, /undefined.+allocate.+for.+BigDecimal/) { BigDecimal.allocate }
    else
      assert_raise_with_message(TypeError, /allocator undefined for BigDecimal/) { BigDecimal.allocate }
    end
  end

  def test_s_new
    assert_raise_with_message(NoMethodError, /undefined method [`']new'/) { BigDecimal.new("1") }
  end

  def test_s_interpret_loosely
    assert_equal(BigDecimal('1'), BigDecimal.interpret_loosely("1__1_1"))
    assert_equal(BigDecimal('2.5'), BigDecimal.interpret_loosely("2.5"))
    assert_equal(BigDecimal('2.5'), BigDecimal.interpret_loosely("2.5 degrees"))
    assert_equal(BigDecimal('2.5e1'), BigDecimal.interpret_loosely("2.5e1 degrees"))
    assert_equal(BigDecimal('0'), BigDecimal.interpret_loosely("degrees 100.0"))
    assert_equal(BigDecimal('0.125'), BigDecimal.interpret_loosely("0.1_2_5"))
    assert_equal(BigDecimal('0.125'), BigDecimal.interpret_loosely("0.1_2_5__"))
    assert_equal(BigDecimal('1'), BigDecimal.interpret_loosely("1_.125"))
    assert_equal(BigDecimal('1'), BigDecimal.interpret_loosely("1._125"))
    assert_equal(BigDecimal('0.1'), BigDecimal.interpret_loosely("0.1__2_5"))
    assert_equal(BigDecimal('0.1'), BigDecimal.interpret_loosely("0.1_e10"))
    assert_equal(BigDecimal('0.1'), BigDecimal.interpret_loosely("0.1e_10"))
    assert_equal(BigDecimal('1'), BigDecimal.interpret_loosely("0.1e1__0"))
    assert_equal(BigDecimal('1.2'), BigDecimal.interpret_loosely("1.2.3"))
    assert_equal(BigDecimal('1'), BigDecimal.interpret_loosely("1."))
    assert_equal(BigDecimal('1'), BigDecimal.interpret_loosely("1e"))

    assert_equal(BigDecimal('0.0'), BigDecimal.interpret_loosely("invalid"))

    assert(BigDecimal.interpret_loosely("2.5").frozen?)
  end

  def _test_mode(type)
    BigDecimal.mode(type, true)
    assert_raise(FloatDomainError) { yield }

    BigDecimal.mode(type, false)
    assert_nothing_raised { yield }
  end

  def test_mode
    assert_raise(ArgumentError) { BigDecimal.mode(BigDecimal::EXCEPTION_ALL, 1) }
    assert_raise(ArgumentError) { BigDecimal.mode(BigDecimal::ROUND_MODE, 256) }
    assert_raise(ArgumentError) { BigDecimal.mode(BigDecimal::ROUND_MODE, :xyzzy) }
    assert_raise(TypeError) { BigDecimal.mode(0xf000, true) }

    begin
      saved_mode = BigDecimal.mode(BigDecimal::ROUND_MODE)

      [ BigDecimal::ROUND_UP,
        BigDecimal::ROUND_DOWN,
        BigDecimal::ROUND_HALF_UP,
        BigDecimal::ROUND_HALF_DOWN,
        BigDecimal::ROUND_CEILING,
        BigDecimal::ROUND_FLOOR,
        BigDecimal::ROUND_HALF_EVEN,
      ].each do |mode|
        BigDecimal.mode(BigDecimal::ROUND_MODE, mode)
        assert_equal(mode, BigDecimal.mode(BigDecimal::ROUND_MODE))
      end
    ensure
      BigDecimal.mode(BigDecimal::ROUND_MODE, saved_mode)
    end

    BigDecimal.save_rounding_mode do
      ROUNDING_MODE_MAP.each do |const, sym|
        BigDecimal.mode(BigDecimal::ROUND_MODE, sym)
        assert_equal(const, BigDecimal.mode(BigDecimal::ROUND_MODE))
      end
    end
  end

  def test_thread_local_mode
    begin
      saved_mode = BigDecimal.mode(BigDecimal::ROUND_MODE)

      BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_UP)
      Thread.start {
        BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_HALF_EVEN)
        assert_equal(BigDecimal::ROUND_HALF_EVEN, BigDecimal.mode(BigDecimal::ROUND_MODE))
      }.join
      assert_equal(BigDecimal::ROUND_UP, BigDecimal.mode(BigDecimal::ROUND_MODE))
    ensure
      BigDecimal.mode(BigDecimal::ROUND_MODE, saved_mode)
    end
  end

  def test_save_exception_mode
    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    mode = BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW)
    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, true)
    end
    assert_equal(mode, BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW))

    BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_FLOOR)
    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_HALF_EVEN)
    end
    assert_equal(BigDecimal::ROUND_HALF_EVEN, BigDecimal.mode(BigDecimal::ROUND_MODE))

    assert_equal(42, BigDecimal.save_exception_mode { 42 })
  end

  def test_save_rounding_mode
    saved_mode = BigDecimal.mode(BigDecimal::ROUND_MODE)

    BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_FLOOR)
    BigDecimal.save_rounding_mode do
      BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_HALF_EVEN)
    end
    assert_equal(BigDecimal::ROUND_FLOOR, BigDecimal.mode(BigDecimal::ROUND_MODE))

    assert_equal(42, BigDecimal.save_rounding_mode { 42 })
  ensure
    BigDecimal.mode(BigDecimal::ROUND_MODE, saved_mode)
  end

  def test_save_limit
    begin
      old = BigDecimal.limit
      BigDecimal.limit(100)
      BigDecimal.save_limit do
        BigDecimal.limit(200)
      end
      assert_equal(100, BigDecimal.limit);
    ensure
      BigDecimal.limit(old)
    end

    assert_equal(42, BigDecimal.save_limit { 42 })
  end

  def test_exception_nan
    _test_mode(BigDecimal::EXCEPTION_NaN) { BigDecimal("NaN") }
  end

  def test_exception_infinity
    _test_mode(BigDecimal::EXCEPTION_INFINITY) { BigDecimal("Infinity") }
  end

  def test_exception_underflow
    _test_mode(BigDecimal::EXCEPTION_UNDERFLOW) do
      x = BigDecimal("0.1")
      100.times do
        x *= x
      end
    end
  end

  def test_exception_overflow
    _test_mode(BigDecimal::EXCEPTION_OVERFLOW) do
      x = BigDecimal("10")
      100.times do
        x *= x
      end
    end
  end

  def test_add_sub_underflow
    BigDecimal.mode(BigDecimal::EXCEPTION_UNDERFLOW, false)
    x = BigDecimal("0.100000000002E#{EXPONENT_MIN + 10}")
    y = BigDecimal("0.100000000001E#{EXPONENT_MIN + 10}")
    z = BigDecimal("0.101E#{EXPONENT_MIN + 10}")
    assert_not_equal(0, x - z)
    assert_not_equal(0, z - y)
    assert_positive_zero(x + (-y))
    assert_positive_zero(x - y)
    assert_positive_zero((-y) - (-x))
    assert_negative_zero((-x) + y)
    assert_negative_zero(y - x)
    assert_negative_zero((-x) - (-y))
  end

  def test_mult_div_overflow_underflow_sign
    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_UNDERFLOW, false)
    large_x = BigDecimal("0.1E#{EXPONENT_MAX}")
    small_x = BigDecimal("0.1E#{EXPONENT_MIN}")

    assert_positive_infinite(large_x * 10)
    assert_positive_infinite(10 * large_x)
    assert_positive_infinite(large_x * large_x)
    assert_negative_infinite(large_x * (-large_x))
    assert_negative_infinite((-large_x) * large_x)
    assert_positive_infinite((-large_x) * (-large_x))

    assert_positive_zero(small_x * 0.1)
    assert_positive_zero(0.1 * small_x)
    assert_positive_zero(small_x * small_x)
    assert_negative_zero(small_x * (-small_x))
    assert_negative_zero((-small_x) * small_x)
    assert_positive_zero((-small_x) * (-small_x))

    assert_positive_infinite(large_x.div(0.1, 10))
    assert_positive_infinite(large_x.div(small_x, 10))
    assert_negative_infinite(large_x.div(-small_x, 10))
    assert_negative_infinite((-large_x).div(small_x, 10))
    assert_positive_infinite((-large_x).div(-small_x, 10))

    assert_positive_zero(small_x.div(10, 10))
    assert_positive_zero(small_x.div(large_x, 10))
    assert_negative_zero(small_x.div(-large_x, 10))
    assert_negative_zero((-small_x).div(large_x, 10))
    assert_positive_zero((-small_x).div(-large_x, 10))
  end

  def test_exception_zerodivide
    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    _test_mode(BigDecimal::EXCEPTION_ZERODIVIDE) { 1 / BigDecimal("0") }
    _test_mode(BigDecimal::EXCEPTION_ZERODIVIDE) { -1 / BigDecimal("0") }
  end

  def test_round_up
    n4 = BigDecimal("4") # n4 / 9 = 0.44444...
    n5 = BigDecimal("5") # n5 / 9 = 0.55555...
    n6 = BigDecimal("6") # n6 / 9 = 0.66666...
    m4, m5, m6 = -n4, -n5, -n6
    n2h = BigDecimal("2.5")
    n3h = BigDecimal("3.5")
    m2h, m3h = -n2h, -n3h

    BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_UP)
    assert_operator(n4, :<, n4 / 9 * 9)
    assert_operator(n5, :<, n5 / 9 * 9)
    assert_operator(n6, :<, n6 / 9 * 9)
    assert_operator(m4, :>, m4 / 9 * 9)
    assert_operator(m5, :>, m5 / 9 * 9)
    assert_operator(m6, :>, m6 / 9 * 9)
    assert_equal(3, n2h.round)
    assert_equal(4, n3h.round)
    assert_equal(-3, m2h.round)
    assert_equal(-4, m3h.round)

    BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_DOWN)
    assert_operator(n4, :>, n4 / 9 * 9)
    assert_operator(n5, :>, n5 / 9 * 9)
    assert_operator(n6, :>, n6 / 9 * 9)
    assert_operator(m4, :<, m4 / 9 * 9)
    assert_operator(m5, :<, m5 / 9 * 9)
    assert_operator(m6, :<, m6 / 9 * 9)
    assert_equal(2, n2h.round)
    assert_equal(3, n3h.round)
    assert_equal(-2, m2h.round)
    assert_equal(-3, m3h.round)

    BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_HALF_UP)
    assert_operator(n4, :>, n4 / 9 * 9)
    assert_operator(n5, :<, n5 / 9 * 9)
    assert_operator(n6, :<, n6 / 9 * 9)
    assert_operator(m4, :<, m4 / 9 * 9)
    assert_operator(m5, :>, m5 / 9 * 9)
    assert_operator(m6, :>, m6 / 9 * 9)
    assert_equal(3, n2h.round)
    assert_equal(4, n3h.round)
    assert_equal(-3, m2h.round)
    assert_equal(-4, m3h.round)

    BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_HALF_DOWN)
    assert_operator(n4, :>, n4 / 9 * 9)
    assert_operator(n5, :<, n5 / 9 * 9)
    assert_operator(n6, :<, n6 / 9 * 9)
    assert_operator(m4, :<, m4 / 9 * 9)
    assert_operator(m5, :>, m5 / 9 * 9)
    assert_operator(m6, :>, m6 / 9 * 9)
    assert_equal(2, n2h.round)
    assert_equal(3, n3h.round)
    assert_equal(-2, m2h.round)
    assert_equal(-3, m3h.round)

    BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_HALF_EVEN)
    assert_operator(n4, :>, n4 / 9 * 9)
    assert_operator(n5, :<, n5 / 9 * 9)
    assert_operator(n6, :<, n6 / 9 * 9)
    assert_operator(m4, :<, m4 / 9 * 9)
    assert_operator(m5, :>, m5 / 9 * 9)
    assert_operator(m6, :>, m6 / 9 * 9)
    assert_equal(2, n2h.round)
    assert_equal(4, n3h.round)
    assert_equal(-2, m2h.round)
    assert_equal(-4, m3h.round)

    BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_CEILING)
    assert_operator(n4, :<, n4 / 9 * 9)
    assert_operator(n5, :<, n5 / 9 * 9)
    assert_operator(n6, :<, n6 / 9 * 9)
    assert_operator(m4, :<, m4 / 9 * 9)
    assert_operator(m5, :<, m5 / 9 * 9)
    assert_operator(m6, :<, m6 / 9 * 9)
    assert_equal(3, n2h.round)
    assert_equal(4, n3h.round)
    assert_equal(-2, m2h.round)
    assert_equal(-3, m3h.round)

    BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_FLOOR)
    assert_operator(n4, :>, n4 / 9 * 9)
    assert_operator(n5, :>, n5 / 9 * 9)
    assert_operator(n6, :>, n6 / 9 * 9)
    assert_operator(m4, :>, m4 / 9 * 9)
    assert_operator(m5, :>, m5 / 9 * 9)
    assert_operator(m6, :>, m6 / 9 * 9)
    assert_equal(2, n2h.round)
    assert_equal(3, n3h.round)
    assert_equal(-3, m2h.round)
    assert_equal(-4, m3h.round)
  end

  def test_zero_p
    BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)

    assert_equal(true, BigDecimal("0").zero?)
    assert_equal(true, BigDecimal("-0").zero?)
    assert_equal(false, BigDecimal("1").zero?)
    assert_equal(true, BigDecimal("0E200000000000000").zero?)
    assert_equal(false, BigDecimal("Infinity").zero?)
    assert_equal(false, BigDecimal("-Infinity").zero?)
    assert_equal(false, BigDecimal("NaN").zero?)
  end

  def test_nonzero_p
    BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)

    assert_equal(nil, BigDecimal("0").nonzero?)
    assert_equal(nil, BigDecimal("-0").nonzero?)
    assert_equal(BigDecimal("1"), BigDecimal("1").nonzero?)
    assert_positive_infinite(BigDecimal("Infinity").nonzero?)
    assert_negative_infinite(BigDecimal("-Infinity").nonzero?)
    assert_nan(BigDecimal("NaN").nonzero?)
  end

  def test_double_fig
    assert_kind_of(Integer, BigDecimal.double_fig)
  end

  def test_cmp
    n1 = BigDecimal("1")
    n2 = BigDecimal("2")
    assert_equal( 0, n1 <=> n1)
    assert_equal( 1, n2 <=> n1)
    assert_equal(-1, n1 <=> n2)
    assert_operator(n1, :==, n1)
    assert_operator(n1, :!=, n2)
    assert_operator(n1, :<, n2)
    assert_operator(n1, :<=, n1)
    assert_operator(n1, :<=, n2)
    assert_operator(n2, :>, n1)
    assert_operator(n2, :>=, n1)
    assert_operator(n1, :>=, n1)

    assert_operator(BigDecimal("-0"), :==, BigDecimal("0"))
    assert_operator(BigDecimal("0"), :<, BigDecimal("1"))
    assert_operator(BigDecimal("1"), :>, BigDecimal("0"))
    assert_operator(BigDecimal("1"), :>, BigDecimal("-1"))
    assert_operator(BigDecimal("-1"), :<, BigDecimal("1"))
    assert_operator(BigDecimal((2**100).to_s), :>, BigDecimal("1"))
    assert_operator(BigDecimal("1"), :<, BigDecimal((2**100).to_s))

    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    inf = BigDecimal("Infinity")
    assert_operator(inf, :>, 1)
    assert_operator(1, :<, inf)

    assert_operator(BigDecimal("1E-1"), :==, 10**(-1), '#4825')
    assert_equal(0, BigDecimal("1E-1") <=> 10**(-1), '#4825')
  end

  def test_cmp_issue9192
    bug9192 = '[ruby-core:58756] [#9192]'
    operators = { :== => :==, :< => :>, :> => :<, :<= => :>=, :>= => :<= }
    5.upto(8) do |i|
      s = "706.0#{i}"
      d = BigDecimal(s)
      f = s.to_f
      operators.each do |op, inv|
        assert_equal(d.send(op, f), f.send(inv, d),
                     "(BigDecimal(#{s.inspect}) #{op} #{s}) and (#{s} #{inv} BigDecimal(#{s.inspect})) is different #{bug9192}")
      end
    end
  end

  def test_cmp_nan
    n1 = BigDecimal("1")
    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
    assert_equal(nil, BigDecimal("NaN") <=> n1)
    assert_equal(false, BigDecimal("NaN") > n1)
    assert_equal(nil, BigDecimal("NaN") <=> BigDecimal("NaN"))
    assert_equal(false, BigDecimal("NaN") == BigDecimal("NaN"))
  end

  def test_cmp_failing_coercion
    n1 = BigDecimal("1")
    assert_equal(nil, n1 <=> nil)
    assert_raise(ArgumentError){n1 > nil}
  end

  def test_cmp_coerce
    n1 = BigDecimal("1")
    n2 = BigDecimal("2")
    o1 = Object.new; def o1.coerce(x); [x, BigDecimal("1")]; end
    o2 = Object.new; def o2.coerce(x); [x, BigDecimal("2")]; end
    assert_equal( 0, n1 <=> o1)
    assert_equal( 1, n2 <=> o1)
    assert_equal(-1, n1 <=> o2)
    assert_operator(n1, :==, o1)
    assert_operator(n1, :!=, o2)
    assert_operator(n1, :<, o2)
    assert_operator(n1, :<=, o1)
    assert_operator(n1, :<=, o2)
    assert_operator(n2, :>, o1)
    assert_operator(n2, :>=, o1)
    assert_operator(n1, :>=, 1)

    bug10109 = '[ruby-core:64190]'
    BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
    assert_operator(BigDecimal(0), :<, Float::INFINITY, bug10109)
    assert_operator(Float::INFINITY, :>, BigDecimal(0), bug10109)
  end

  def test_cmp_bignum
    assert_operator(BigDecimal((2**100).to_s), :==, 2**100)
  end

  def test_cmp_data
    d = Time.now; def d.coerce(x); [x, x]; end
    assert_operator(BigDecimal((2**100).to_s), :==, d)
  end

  def test_precs_deprecated
    assert_warn(/BigDecimal#precs is deprecated and will be removed in the future/) do
      Warning[:deprecated] = true if defined?(Warning.[])
      BigDecimal("1").precs
    end
  end

  def test_precs
    assert_separately(["-rbigdecimal"], "#{<<~"begin;"}\n#{<<~'end;'}")
    begin;
      $VERBOSE = nil
      a = BigDecimal("1").precs
      assert_instance_of(Array, a)
      assert_equal(2, a.size)
      assert_kind_of(Integer, a[0])
      assert_kind_of(Integer, a[1])
    end;
  end

  def test_hash
    a = []
    b = BigDecimal("1")
    10.times { a << b *= 10 }
    h = {}
    a.each_with_index {|x, i| h[x] = i }
    a.each_with_index do |x, i|
      assert_equal(i, h[x])
    end
  end

  def test_marshal
    s = Marshal.dump(BigDecimal("1", 1))
    assert_equal(BigDecimal("1", 1), Marshal.load(s))

    # corrupt data
    s = s.gsub(/BigDecimal.*\z/m) {|x| x.gsub(/\d/m, "-") }
    assert_raise(TypeError) { Marshal.load(s) }
  end

  def test_dump_extra_high_maxprec
    m = BigDecimal(2 ** 1000)
    n = BigDecimal(2) ** 1000
    # Even if two bigdecimals have different MaxPrec,
    # _dump should return same string if they represent the same value.
    assert_equal(m._dump, n._dump)
  end

  def test_load_invalid_precision
    $VERBOSE, verbose = nil, $VERBOSE
    dumped = BigDecimal('1' * 1000)._dump
    n = BigDecimal._load(dumped)
    digits_part = dumped.split(':').last
    too_few_precs = BigDecimal._load('100:' + digits_part)
    assert_equal(1000, too_few_precs.precision)
    assert_equal(n, too_few_precs)
    assert_equal(n.precs, too_few_precs.precs)
    too_large_precs = BigDecimal._load('999999999999:' + digits_part)
    assert_equal(1000, too_large_precs.precision)
    assert_equal(n, too_large_precs)
    assert_equal(n.precs, too_large_precs.precs)
  ensure
    $VERBOSE = verbose
  end

  def test_finite_infinite_nan
    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_ZERODIVIDE, false)

    x = BigDecimal("0")
    assert_equal(true, x.finite?)
    assert_equal(nil, x.infinite?)
    assert_equal(false, x.nan?)
    y = 1 / x
    assert_equal(false, y.finite?)
    assert_equal(1, y.infinite?)
    assert_equal(false, y.nan?)
    y = -1 / x
    assert_equal(false, y.finite?)
    assert_equal(-1, y.infinite?)
    assert_equal(false, y.nan?)

    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
    y = 0 / x
    assert_equal(false, y.finite?)
    assert_equal(nil, y.infinite?)
    assert_equal(true, y.nan?)
  end

  def test_to_i
    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)

    x = BigDecimal("0")
    assert_kind_of(Integer, x.to_i)
    assert_equal(0, x.to_i)
    assert_raise(FloatDomainError){( 1 / x).to_i}
    assert_raise(FloatDomainError){(-1 / x).to_i}
    assert_raise(FloatDomainError) {( 0 / x).to_i}
    x = BigDecimal("1")
    assert_equal(1, x.to_i)
    x = BigDecimal((2**100).to_s)
    assert_equal(2**100, x.to_i)
  end

  def test_to_f
    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_ZERODIVIDE, false)

    x = BigDecimal("0")
    assert_instance_of(Float, x.to_f)
    assert_equal(0.0, x.to_f)
    assert_equal( 1.0 / 0.0, ( 1 / x).to_f)
    assert_equal(-1.0 / 0.0, (-1 / x).to_f)
    assert_nan(( 0 / x).to_f)
    x = BigDecimal("1")
    assert_equal(1.0, x.to_f)
    x = BigDecimal((2**100).to_s)
    assert_equal((2**100).to_f, x.to_f)
    x = BigDecimal("1" + "0" * 10000)
    assert_equal(0, BigDecimal("-0").to_f)

    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, true)
    assert_raise(FloatDomainError) { x.to_f }
    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    assert_kind_of(Float,   x .to_f)
    assert_kind_of(Float, (-x).to_f)

    bug6944 = '[ruby-core:47342]'

    BigDecimal.mode(BigDecimal::EXCEPTION_UNDERFLOW, true)
    x = "1e#{Float::MIN_10_EXP - 2*Float::DIG}"
    assert_raise(FloatDomainError, x) {BigDecimal(x).to_f}
    x = "-#{x}"
    assert_raise(FloatDomainError, x) {BigDecimal(x).to_f}
    x = "1e#{Float::MIN_10_EXP - Float::DIG}"
    assert_nothing_raised(FloatDomainError, x) {
      assert_in_delta(0.0, BigDecimal(x).to_f, 10**Float::MIN_10_EXP, bug6944)
    }
    x = "-#{x}"
    assert_nothing_raised(FloatDomainError, x) {
      assert_in_delta(0.0, BigDecimal(x).to_f, 10**Float::MIN_10_EXP, bug6944)
    }

    BigDecimal.mode(BigDecimal::EXCEPTION_UNDERFLOW, false)
    x = "1e#{Float::MIN_10_EXP - 2*Float::DIG}"
    assert_equal( 0.0, BigDecimal(x).to_f, x)
    x = "-#{x}"
    assert_equal(-0.0, BigDecimal(x).to_f, x)
    x = "1e#{Float::MIN_10_EXP - Float::DIG}"
    assert_nothing_raised(FloatDomainError, x) {
      assert_in_delta(0.0, BigDecimal(x).to_f, 10**Float::MIN_10_EXP, bug6944)
    }
    x = "-#{x}"
    assert_nothing_raised(FloatDomainError, x) {
      assert_in_delta(0.0, BigDecimal(x).to_f, 10**Float::MIN_10_EXP, bug6944)
    }

    assert_equal( 0.0, BigDecimal(  '9e-325').to_f)
    assert_equal( 0.0, BigDecimal( '10e-325').to_f)
    assert_equal(-0.0, BigDecimal( '-9e-325').to_f)
    assert_equal(-0.0, BigDecimal('-10e-325').to_f)
  end

  def test_to_r
    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)

    x = BigDecimal("0")
    assert_kind_of(Rational, x.to_r)
    assert_equal(0, x.to_r)
    assert_raise(FloatDomainError) {( 1 / x).to_r}
    assert_raise(FloatDomainError) {(-1 / x).to_r}
    assert_raise(FloatDomainError) {( 0 / x).to_r}

    assert_equal(1, BigDecimal("1").to_r)
    assert_equal(Rational(3, 2), BigDecimal("1.5").to_r)
    assert_equal((2**100).to_r, BigDecimal((2**100).to_s).to_r)
  end

  def test_coerce
    a, b = BigDecimal("1").coerce(1.0)
    assert_instance_of(BigDecimal, a)
    assert_instance_of(BigDecimal, b)
    assert_equal(2, 1 + BigDecimal("1"), '[ruby-core:25697]')

    a, b = BigDecimal("1").coerce(1.quo(10))
    assert_equal(BigDecimal("0.1"), a, '[ruby-core:34318]')

    a, b = BigDecimal("0.11111").coerce(1.quo(3))
    assert_equal(BigDecimal("0." + "3"*a.precision), a)

    assert_nothing_raised(TypeError, '#7176') do
      BigDecimal('1') + Rational(1)
    end
  end

  def test_coerce_rational
    assert_in_epsilon(3.0 / 7.0, BigDecimal(1) / (7/3r), 1e-15)
    assert_in_epsilon(10.0 / 3.0, BigDecimal(1) + (7/3r), 1e-15)
    assert_in_epsilon(2.0 / 3.0, BigDecimal(3) - (7/3r), 1e-15)
    assert_in_epsilon(14.0 / 3.0, BigDecimal(2) * (7/3r), 1e-15)
    assert_in_epsilon(BigDecimal(3).div(7, 100), BigDecimal(1).div(7/3r, 100), 1e-99)
    assert_in_epsilon(BigDecimal(10).div(3, 100), BigDecimal(1).add(7/3r, 100), 1e-99)
    assert_in_epsilon(BigDecimal(2).div(3, 100), BigDecimal(3).sub(7/3r, 100), 1e-99)
    assert_in_epsilon(BigDecimal(14).div(3, 100), BigDecimal(2).mult(7/3r, 100), 1e-99)
  end

  def test_uplus
    x = BigDecimal("1")
    assert_equal(x, x.send(:+@))
  end

  def test_neg
    BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)

    assert_equal(BigDecimal("-1"), BigDecimal("1").send(:-@))
    assert_equal(BigDecimal("-0"), BigDecimal("0").send(:-@))
    assert_equal(BigDecimal("0"), BigDecimal("-0").send(:-@))
    assert_equal(BigDecimal("-Infinity"), BigDecimal("Infinity").send(:-@))
    assert_equal(BigDecimal("Infinity"), BigDecimal("-Infinity").send(:-@))
    assert_equal(true, BigDecimal("NaN").send(:-@).nan?)
  end

  def test_add
    x = BigDecimal("1")
    assert_equal(BigDecimal("2"), x + x)
    assert_equal(1, BigDecimal("0") + 1)
    assert_equal(1, x + 0)

    assert_equal(BigDecimal::SIGN_POSITIVE_ZERO, (BigDecimal("0") + 0).sign)
    assert_equal(BigDecimal::SIGN_POSITIVE_ZERO, (BigDecimal("-0") + 0).sign)
    assert_equal(BigDecimal::SIGN_NEGATIVE_ZERO, (BigDecimal("-0") + BigDecimal("-0")).sign)

    x = BigDecimal((2**100).to_s)
    assert_equal(BigDecimal((2**100+1).to_s), x + 1)

    BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
    inf    = BigDecimal("Infinity")
    neginf = BigDecimal("-Infinity")

    BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, true)
    assert_raise_with_message(FloatDomainError, "Computation results to 'Infinity'") { inf + inf }
    assert_raise_with_message(FloatDomainError, "Computation results to '-Infinity'") { neginf + neginf }
  end

  def test_sub
    x = BigDecimal("1")
    assert_equal(BigDecimal("0"), x - x)
    assert_equal(-1, BigDecimal("0") - 1)
    assert_equal(1, x - 0)

    assert_equal(BigDecimal::SIGN_POSITIVE_ZERO, (BigDecimal("0") - 0).sign)
    assert_equal(BigDecimal::SIGN_NEGATIVE_ZERO, (BigDecimal("-0") - 0).sign)
    assert_equal(BigDecimal::SIGN_POSITIVE_ZERO, (BigDecimal("-0") - BigDecimal("-0")).sign)

    x = BigDecimal((2**100).to_s)
    assert_equal(BigDecimal((2**100-1).to_s), x - 1)

    BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
    inf    = BigDecimal("Infinity")
    neginf = BigDecimal("-Infinity")

    BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, true)
    assert_raise_with_message(FloatDomainError, "Computation results to 'Infinity'") { inf - neginf }
    assert_raise_with_message(FloatDomainError, "Computation results to '-Infinity'") { neginf - inf }
  end

  def test_sub_with_float
    assert_kind_of(BigDecimal, BigDecimal("3") - 1.0)
  end

  def test_sub_with_rational
    assert_kind_of(BigDecimal, BigDecimal("3") - 1.quo(3))
  end

  def test_mult
    x = BigDecimal((2**100).to_s)
    assert_equal(BigDecimal((2**100 * 3).to_s), (x * 3).to_i)
    assert_equal(x, (x * 1).to_i)
    assert_equal(x, (BigDecimal("1") * x).to_i)
    assert_equal(BigDecimal((2**200).to_s), (x * x).to_i)

    BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
    inf    = BigDecimal("Infinity")
    neginf = BigDecimal("-Infinity")

    BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, true)
    assert_raise_with_message(FloatDomainError, "Computation results to 'Infinity'") { inf * inf }
    assert_raise_with_message(FloatDomainError, "Computation results to '-Infinity'") { neginf * inf }
  end

  def test_mult_with_float
    assert_kind_of(BigDecimal, BigDecimal("3") * 1.5)
    assert_equal(BigDecimal("64.4"), BigDecimal(1) * 64.4)
  end

  def test_mult_with_rational
    assert_kind_of(BigDecimal, BigDecimal("3") * 1.quo(3))
  end

  def test_mult_with_nil
    assert_raise(TypeError) {
      BigDecimal('1.1') * nil
    }
  end

  def test_div
    x = BigDecimal((2**100).to_s)
    assert_equal(BigDecimal((2**100 / 3).to_s), (x / 3).to_i)
    assert_equal(BigDecimal::SIGN_POSITIVE_ZERO, (BigDecimal("0") / 1).sign)
    assert_equal(BigDecimal::SIGN_NEGATIVE_ZERO, (BigDecimal("-0") / 1).sign)
    assert_equal(2, BigDecimal("2") / 1)
    assert_equal(-2, BigDecimal("2") / -1)

    assert_equal(BigDecimal('1486.868686869'),
                 (BigDecimal('1472.0') / BigDecimal('0.99')).round(9),
                 '[ruby-core:59365] [#9316]')

    assert_in_delta(4.124045235,
                    (BigDecimal('0.9932') / (700 * BigDecimal('0.344045') / BigDecimal('1000.0'))).round(9, half: :up),
                    10**Float::MIN_10_EXP, '[#9305]')

    BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
    assert_positive_zero(BigDecimal("1.0")  / BigDecimal("Infinity"))
    assert_negative_zero(BigDecimal("-1.0") / BigDecimal("Infinity"))
    assert_negative_zero(BigDecimal("1.0")  / BigDecimal("-Infinity"))
    assert_positive_zero(BigDecimal("-1.0") / BigDecimal("-Infinity"))

    BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, true)
    BigDecimal.mode(BigDecimal::EXCEPTION_ZERODIVIDE, false)
    assert_raise_with_message(FloatDomainError, "Computation results in 'Infinity'") { BigDecimal("1") / 0 }
    assert_raise_with_message(FloatDomainError, "Computation results in '-Infinity'") { BigDecimal("-1") / 0 }
  end

  def test_div_gh220
    x = BigDecimal("1.0")
    y = BigDecimal("3672577333.6608990499165058135986328125")
    c = BigDecimal("0.272288343892592687909520102748926752911779209181321745e-9")
    assert_equal(c, x / y, "[GH-220]")
  end

  def test_div_precision
    bug13754 = '[ruby-core:82107] [Bug #13754]'
    a = BigDecimal('101')
    b = BigDecimal('0.9163472602589686')
    c = a/b
    assert(c.precision > b.precision,
           "(101/0.9163472602589686).precision >= (0.9163472602589686).precision #{bug13754}")
  end

  def test_div_various_precisions
    a_precs = [5, 20, 70]
    b_precs = [*5..80]
    exponents = [-5, 0, 5]
    a_precs.product(exponents, b_precs, exponents).each do |prec_a, ex_a, prec_b, ex_b|
      a = BigDecimal('7.' + '1' * (prec_a - 1) + "e#{ex_a}")
      b = BigDecimal('3.' + '1' * (prec_b - 1) + "e#{ex_b}")
      c = a / b
      max = [prec_a, prec_b, BigDecimal.double_fig].max
      # Precision must be enough and not too large
      precision_min = max + BigDecimal.double_fig / 2
      precision_max = max + 2 * BigDecimal.double_fig
      assert_includes(precision_min..precision_max, c.n_significant_digits)
      assert_in_delta(a, c * b, a * 10**(1 - precision_min))
    end
  end

  def test_div_round_worst_precision_case
    x = BigDecimal(5)
    y = BigDecimal(9 * BASE / 10)
    (BASE_FIG * 2..BASE_FIG * 4).each do |prec|
      assert_equal(BigDecimal('0.' + '5' * (prec - 1) + "6E-#{BASE_FIG - 1}"), x.div(y, prec))
    end
  end

  def test_div_rounding_with_small_remainder
    BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_HALF_UP)
    assert_equal(BigDecimal('0.12e1'), BigDecimal('1.25').div(BigDecimal("1.#{'0' * 30}1"), 2))

    BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_HALF_DOWN)
    assert_equal(BigDecimal('0.500000002e0'), BigDecimal('1.000000005').div(2, 9))
    assert_equal(BigDecimal('0.500000003e0'), BigDecimal('1.0000000050000000000001').div(2, 9))
    assert_equal(BigDecimal('0.3333333333e0'), BigDecimal(1).div(3, 10))
    assert_equal(BigDecimal('0.3333333333333333333333333333333333333333e0'), BigDecimal(1).div(3, 40))
    assert_equal(BigDecimal("0.5000000000000000000000000000000000000002e0"), BigDecimal("1.#{'0' * 39}5").div(2, 40))
    assert_equal(BigDecimal("0.5000000000000000000000000000000000000003e0"), BigDecimal("1.#{'0' * 39}5#{'0' * 40}1").div(2, 40))
    assert_equal(BigDecimal("0.5000000000000000000000000000000000000000e0"), BigDecimal("1.#{'0' * 39}1").div(2, 40))
    assert_equal(BigDecimal("0.5000000000000000000000000000000000000001e0"), BigDecimal("1.#{'0' * 39}1#{'0' * 40}1").div(2, 40))

    BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_UP)
    assert_equal(BigDecimal('0.3333333334e0'), BigDecimal(1).div(3, 10))
    assert_equal(BigDecimal('0.3333333333333333333333333333333333333334e0'), BigDecimal(1).div(3, 40))
    assert_equal(BigDecimal("0.1000000000000000000000000000000000000001e1"), BigDecimal("3.#{'0' * 40}1").div(3, 40))
    assert_equal(BigDecimal("0.1000000000000000000000000000000000000001e1"), BigDecimal("3.#{'0' * 60}1").div(3, 40))
    assert_equal(BigDecimal("0.100000000000000000000000000001e1"), BigDecimal("3.#{'0' * 40}1").div(3, 30))
    assert_equal(BigDecimal("0.10000000000000000001e1"), BigDecimal("3.#{'0' * 40}1").div(3, 20))
    assert_equal(BigDecimal("0.10000000000000000001e6"), BigDecimal("3.#{'0' * 40}1e5").div(3, 20))
  end

  def test_div_with_float
    assert_kind_of(BigDecimal, BigDecimal("3") / 1.5)
    assert_equal(BigDecimal("0.5"), BigDecimal(1) / 2.0)
    assert_equal(BigDecimal(100), BigDecimal(7).div(0.07, 100))
  end

  def test_div_with_rational
    assert_kind_of(BigDecimal, BigDecimal("3") / 1.quo(3))
  end

  def test_div_with_complex
    q = BigDecimal("3") / 1i
    assert_kind_of(Complex, q)
  end

  def test_div_error
    assert_raise(TypeError) { BigDecimal(20) / '2' }
  end

  def test_mod
    x = BigDecimal((2**100).to_s)
    assert_equal(1, x % 3)
    assert_equal(2, (-x) % 3)
    assert_equal(-2, x % -3)
    assert_equal(-1, (-x) % -3)
  end

  def test_mod_with_float
    assert_kind_of(BigDecimal, BigDecimal("3") % 1.5)
  end

  def test_mod_with_rational
    assert_kind_of(BigDecimal, BigDecimal("3") % 1.quo(3))
  end

  def test_remainder
    x = BigDecimal((2**100).to_s)
    assert_equal(1, x.remainder(3))
    assert_equal(-1, (-x).remainder(3))
    assert_equal(1, x.remainder(-3))
    assert_equal(-1, (-x).remainder(-3))
    assert_equal(BigDecimal("1e-10"), BigDecimal("1e10").remainder(BigDecimal("3e-10")))
  end

  def test_remainder_with_float
    assert_kind_of(BigDecimal, BigDecimal("3").remainder(1.5))
  end

  def test_remainder_with_rational
    assert_kind_of(BigDecimal, BigDecimal("3").remainder(1.quo(3)))
  end

  def test_remainder_coerce
    o = Object.new
    def o.coerce(x); [x, BigDecimal("-3")]; end
    assert_equal(BigDecimal("1.1"), BigDecimal("7.1").remainder(o))
  end

  def test_divmod
    x = BigDecimal((2**100).to_s)
    assert_equal([(x / 3).floor, 1], x.divmod(3))
    assert_equal([(-x / 3).floor, 2], (-x).divmod(3))

    assert_equal([0, 0], BigDecimal("0").divmod(2))

    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
    assert_raise(ZeroDivisionError){BigDecimal("0").divmod(0)}
  end

  def test_divmod_precision
    a = BigDecimal('2e55')
    b = BigDecimal('1.23456789e10')
    q, r = a.divmod(b)
    assert_equal((a/b).round(0, :down), q)
    assert_equal((a - q*b), r)

    b = BigDecimal('-1.23456789e10')
    q, r = a.divmod(b)
    assert_equal((a/b).round(0, :down) - 1, q)
    assert_equal((a - q*b), r)

    a = BigDecimal('3e100')
    b = BigDecimal('-1.7e-100')
    q, r = a.divmod(b)
    assert_include(0...-b, -r)
    assert_equal((a - q*b), r)

    a = BigDecimal('0.32e23')
    b = BigDecimal('-0.1999999999e-23')
    q, r = a.divmod(b)
    assert_include(0...-b, -r)
    assert_equal((a - q*b), r)

    a = BigDecimal('199.9999999999999999999999999')
    q, r = a.divmod(1)
    assert_equal([199, a - 199], [q, r])

    a = BigDecimal('0.30000000000000000000000000000000000000000000000000000000000000001e91')
    b = BigDecimal('0.1e20')
    q, r = a.divmod(b)
    assert_include(0...b, r)
    assert_equal((a - q*b), r)
  end

  def test_divmod_error
    assert_raise(TypeError) { BigDecimal(20).divmod('2') }
  end

  def test_add_bigdecimal
    x = BigDecimal((2**100).to_s)
    assert_equal(3000000000000000000000000000000, x.add(x, 1))
    assert_equal(2500000000000000000000000000000, x.add(x, 2))
    assert_equal(2540000000000000000000000000000, x.add(x, 3))
  end

  def test_sub_bigdecimal
    x = BigDecimal((2**100).to_s)
    assert_equal(1000000000000000000000000000000, x.sub(1, 1))
    assert_equal(1300000000000000000000000000000, x.sub(1, 2))
    assert_equal(1270000000000000000000000000000, x.sub(1, 3))
  end

  def test_mult_bigdecimal
    x = BigDecimal((2**100).to_s)
    assert_equal(4000000000000000000000000000000, x.mult(3, 1))
    assert_equal(3800000000000000000000000000000, x.mult(3, 2))
    assert_equal(3800000000000000000000000000000, x.mult(3, 3))
  end

  def test_div_bigdecimal
    x = BigDecimal((2**100).to_s)
    assert_equal(422550200076076467165567735125, x.div(3))
    assert_equal(400000000000000000000000000000, x.div(3, 1))
    assert_equal(420000000000000000000000000000, x.div(3, 2))
    assert_equal(423000000000000000000000000000, x.div(3, 3))
    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
      assert_equal(0, BigDecimal("0").div(BigDecimal("Infinity")))
    end
  end

  def test_div_bigdecimal_with_float_and_precision
    x = BigDecimal(5)
    y = 5.1
    assert_equal(x.div(BigDecimal(y, 0), 8),
                 x.div(y, 8))

    assert_equal(x.div(BigDecimal(y, 0), 100),
                 x.div(y, 100))
  end

  def test_quo_without_prec
    x = BigDecimal(5)
    y = BigDecimal(229)
    assert_equal(BigDecimal("0.021834061135371179039301310043668"), x.quo(y))
  end

  def test_quo_with_prec
    begin
      saved_mode = BigDecimal.mode(BigDecimal::ROUND_MODE)
      BigDecimal.mode(BigDecimal::ROUND_MODE, :half_up)

      x = BigDecimal(5)
      y = BigDecimal(229)
      assert_equal(BigDecimal("0.021834061135371179039301310043668"), x.quo(y, 0))
      assert_equal(BigDecimal("0.022"), x.quo(y, 2))
      assert_equal(BigDecimal("0.0218"), x.quo(y, 3))
      assert_equal(BigDecimal("0.0218341"), x.quo(y, 6))
      assert_equal(BigDecimal("0.02183406114"), x.quo(y, 10))
      assert_equal(BigDecimal("0.021834061135371179039301310043668122270742358078603"), x.quo(y, 50))
    ensure
      BigDecimal.mode(BigDecimal::ROUND_MODE, saved_mode)
    end
  end

  def test_abs_bigdecimal
    x = BigDecimal((2**100).to_s)
    assert_equal(1267650600228229401496703205376, x.abs)
    x = BigDecimal("-" + (2**100).to_s)
    assert_equal(1267650600228229401496703205376, x.abs)
    x = BigDecimal("0")
    assert_equal(0, x.abs)
    x = BigDecimal("-0")
    assert_equal(0, x.abs)

    BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
    x = BigDecimal("Infinity")
    assert_equal(BigDecimal("Infinity"), x.abs)
    x = BigDecimal("-Infinity")
    assert_equal(BigDecimal("Infinity"), x.abs)

    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
    x = BigDecimal("NaN")
    assert_nan(x.abs)
  end

  def test_sqrt_bigdecimal
    x = BigDecimal("0.09")
    assert_in_delta(0.3, x.sqrt(1), 0.001)
    x = BigDecimal((2**100).to_s)
    y = BigDecimal("1125899906842624")
    e = y.exponent
    assert_equal(true, (x.sqrt(100) - y).abs < BigDecimal("1E#{e-100}"))
    assert_equal(true, (x.sqrt(200) - y).abs < BigDecimal("1E#{e-200}"))
    assert_equal(true, (x.sqrt(300) - y).abs < BigDecimal("1E#{e-300}"))
    x = BigDecimal("-" + (2**100).to_s)
    assert_raise_with_message(FloatDomainError, "sqrt of negative value") { x.sqrt(1) }
    x = BigDecimal((2**200).to_s)
    assert_equal(2**100, x.sqrt(1))

    assert_in_delta(BigDecimal("4.0000000000000000000125"), BigDecimal("16.0000000000000000001").sqrt(100), BigDecimal("1e-40"))

    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
    assert_raise_with_message(FloatDomainError, "sqrt of 'NaN'(Not a Number)") { BigDecimal("NaN").sqrt(1) }
    assert_raise_with_message(FloatDomainError, "sqrt of negative value") { BigDecimal("-Infinity").sqrt(1) }

    assert_equal(0, BigDecimal("0").sqrt(1))
    assert_equal(0, BigDecimal("-0").sqrt(1))
    assert_equal(1, BigDecimal("1").sqrt(1))
    assert_positive_infinite(BigDecimal("Infinity").sqrt(1))
  end

  def test_sqrt_5266
    x = BigDecimal('2' + '0'*100)
    assert_equal('0.14142135623730950488016887242096980785696718753769480731',
                 x.sqrt(56).to_s(56).split(' ')[0])
    assert_equal('0.1414213562373095048801688724209698078569671875376948073',
                 x.sqrt(55).to_s(55).split(' ')[0])

    x = BigDecimal('2' + '0'*200)
    assert_equal('0.14142135623730950488016887242096980785696718753769480731766797379907324784621070388503875343276415727350138462',
                 x.sqrt(110).to_s(110).split(' ')[0])
    assert_equal('0.1414213562373095048801688724209698078569671875376948073176679737990732478462107038850387534327641572735013846',
                 x.sqrt(109).to_s(109).split(' ')[0])
  end

  def test_fix
    x = BigDecimal("1.1")
    assert_equal(1, x.fix)
    assert_kind_of(BigDecimal, x.fix)
  end

  def test_frac
    x = BigDecimal("1.1")
    assert_equal(0.1, x.frac)
    assert_equal(0.1, BigDecimal("0.1").frac)
    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
    assert_nan(BigDecimal("NaN").frac)
  end

  def test_round
    assert_equal(3, BigDecimal("3.14159").round)
    assert_equal(9, BigDecimal("8.7").round)
    assert_equal(3.142, BigDecimal("3.14159").round(3))
    assert_equal(13300.0, BigDecimal("13345.234").round(-2))

    x = BigDecimal("111.111")
    assert_equal(111    , x.round)
    assert_equal(111.1  , x.round(1))
    assert_equal(111.11 , x.round(2))
    assert_equal(111.111, x.round(3))
    assert_equal(111.111, x.round(4))
    assert_equal(110    , x.round(-1))
    assert_equal(100    , x.round(-2))
    assert_equal(  0    , x.round(-3))
    assert_equal(  0    , x.round(-4))

    x = BigDecimal("2.5")
    assert_equal(3, x.round(0, BigDecimal::ROUND_UP))
    assert_equal(2, x.round(0, BigDecimal::ROUND_DOWN))
    assert_equal(3, x.round(0, BigDecimal::ROUND_HALF_UP))
    assert_equal(2, x.round(0, BigDecimal::ROUND_HALF_DOWN))
    assert_equal(2, x.round(0, BigDecimal::ROUND_HALF_EVEN))
    assert_equal(3, x.round(0, BigDecimal::ROUND_CEILING))
    assert_equal(2, x.round(0, BigDecimal::ROUND_FLOOR))
    assert_raise(ArgumentError) { x.round(0, 256) }

    x = BigDecimal("-2.5")
    assert_equal(-3, x.round(0, BigDecimal::ROUND_UP))
    assert_equal(-2, x.round(0, BigDecimal::ROUND_DOWN))
    assert_equal(-3, x.round(0, BigDecimal::ROUND_HALF_UP))
    assert_equal(-2, x.round(0, BigDecimal::ROUND_HALF_DOWN))
    assert_equal(-2, x.round(0, BigDecimal::ROUND_HALF_EVEN))
    assert_equal(-2, x.round(0, BigDecimal::ROUND_CEILING))
    assert_equal(-3, x.round(0, BigDecimal::ROUND_FLOOR))

    ROUNDING_MODE_MAP.each do |const, sym|
      assert_equal(x.round(0, const), x.round(0, sym))
    end

    bug3803 = '[ruby-core:32136]'
    15.times do |n|
      x = BigDecimal("5#{'0'*n}1")
      assert_equal(10**(n+2), x.round(-(n+2), BigDecimal::ROUND_HALF_DOWN), bug3803)
      assert_equal(10**(n+2), x.round(-(n+2), BigDecimal::ROUND_HALF_EVEN), bug3803)
      x = BigDecimal("0.5#{'0'*n}1")
      assert_equal(1, x.round(0, BigDecimal::ROUND_HALF_DOWN), bug3803)
      assert_equal(1, x.round(0, BigDecimal::ROUND_HALF_EVEN), bug3803)
      x = BigDecimal("-0.5#{'0'*n}1")
      assert_equal(-1, x.round(0, BigDecimal::ROUND_HALF_DOWN), bug3803)
      assert_equal(-1, x.round(0, BigDecimal::ROUND_HALF_EVEN), bug3803)
    end

    assert_instance_of(Integer, x.round)
    assert_instance_of(Integer, x.round(0))
    assert_instance_of(Integer, x.round(-1))
    assert_instance_of(BigDecimal, x.round(1))
  end

  def test_round_half_even
    assert_equal(BigDecimal('12.0'), BigDecimal('12.5').round(half: :even))
    assert_equal(BigDecimal('14.0'), BigDecimal('13.5').round(half: :even))

    assert_equal(BigDecimal('2.2'), BigDecimal('2.15').round(1, half: :even))
    assert_equal(BigDecimal('2.2'), BigDecimal('2.25').round(1, half: :even))
    assert_equal(BigDecimal('2.4'), BigDecimal('2.35').round(1, half: :even))

    assert_equal(BigDecimal('-2.2'), BigDecimal('-2.15').round(1, half: :even))
    assert_equal(BigDecimal('-2.2'), BigDecimal('-2.25').round(1, half: :even))
    assert_equal(BigDecimal('-2.4'), BigDecimal('-2.35').round(1, half: :even))

    assert_equal(BigDecimal('7.1364'), BigDecimal('7.13645').round(4, half: :even))
    assert_equal(BigDecimal('7.1365'), BigDecimal('7.1364501').round(4, half: :even))
    assert_equal(BigDecimal('7.1364'), BigDecimal('7.1364499').round(4, half: :even))

    assert_equal(BigDecimal('-7.1364'), BigDecimal('-7.13645').round(4, half: :even))
    assert_equal(BigDecimal('-7.1365'), BigDecimal('-7.1364501').round(4, half: :even))
    assert_equal(BigDecimal('-7.1364'), BigDecimal('-7.1364499').round(4, half: :even))
  end

  def test_round_half_up
    assert_equal(BigDecimal('13.0'), BigDecimal('12.5').round(half: :up))
    assert_equal(BigDecimal('14.0'), BigDecimal('13.5').round(half: :up))

    assert_equal(BigDecimal('2.2'), BigDecimal('2.15').round(1, half: :up))
    assert_equal(BigDecimal('2.3'), BigDecimal('2.25').round(1, half: :up))
    assert_equal(BigDecimal('2.4'), BigDecimal('2.35').round(1, half: :up))

    assert_equal(BigDecimal('-2.2'), BigDecimal('-2.15').round(1, half: :up))
    assert_equal(BigDecimal('-2.3'), BigDecimal('-2.25').round(1, half: :up))
    assert_equal(BigDecimal('-2.4'), BigDecimal('-2.35').round(1, half: :up))

    assert_equal(BigDecimal('7.1365'), BigDecimal('7.13645').round(4, half: :up))
    assert_equal(BigDecimal('7.1365'), BigDecimal('7.1364501').round(4, half: :up))
    assert_equal(BigDecimal('7.1364'), BigDecimal('7.1364499').round(4, half: :up))

    assert_equal(BigDecimal('-7.1365'), BigDecimal('-7.13645').round(4, half: :up))
    assert_equal(BigDecimal('-7.1365'), BigDecimal('-7.1364501').round(4, half: :up))
    assert_equal(BigDecimal('-7.1364'), BigDecimal('-7.1364499').round(4, half: :up))
  end

  def test_round_half_down
    assert_equal(BigDecimal('12.0'), BigDecimal('12.5').round(half: :down))
    assert_equal(BigDecimal('13.0'), BigDecimal('13.5').round(half: :down))

    assert_equal(BigDecimal('2.1'), BigDecimal('2.15').round(1, half: :down))
    assert_equal(BigDecimal('2.2'), BigDecimal('2.25').round(1, half: :down))
    assert_equal(BigDecimal('2.3'), BigDecimal('2.35').round(1, half: :down))

    assert_equal(BigDecimal('-2.1'), BigDecimal('-2.15').round(1, half: :down))
    assert_equal(BigDecimal('-2.2'), BigDecimal('-2.25').round(1, half: :down))
    assert_equal(BigDecimal('-2.3'), BigDecimal('-2.35').round(1, half: :down))

    assert_equal(BigDecimal('7.1364'), BigDecimal('7.13645').round(4, half: :down))
    assert_equal(BigDecimal('7.1365'), BigDecimal('7.1364501').round(4, half: :down))
    assert_equal(BigDecimal('7.1364'), BigDecimal('7.1364499').round(4, half: :down))

    assert_equal(BigDecimal('-7.1364'), BigDecimal('-7.13645').round(4, half: :down))
    assert_equal(BigDecimal('-7.1365'), BigDecimal('-7.1364501').round(4, half: :down))
    assert_equal(BigDecimal('-7.1364'), BigDecimal('-7.1364499').round(4, half: :down))
  end

  def test_round_half_nil
    x = BigDecimal("2.5")

    BigDecimal.save_rounding_mode do
      BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_UP)
      assert_equal(3, x.round(0, half: nil))
    end

    BigDecimal.save_rounding_mode do
      BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_DOWN)
      assert_equal(2, x.round(0, half: nil))
    end

    BigDecimal.save_rounding_mode do
      BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_HALF_UP)
      assert_equal(3, x.round(0, half: nil))
    end

    BigDecimal.save_rounding_mode do
      BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_HALF_DOWN)
      assert_equal(2, x.round(0, half: nil))
    end

    BigDecimal.save_rounding_mode do
      BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_HALF_EVEN)
      assert_equal(2, x.round(0, half: nil))
    end

    BigDecimal.save_rounding_mode do
      BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_CEILING)
      assert_equal(3, x.round(0, half: nil))
    end

    BigDecimal.save_rounding_mode do
      BigDecimal.mode(BigDecimal::ROUND_MODE, BigDecimal::ROUND_FLOOR)
      assert_equal(2, x.round(0, half: nil))
    end
  end

  def test_round_half_invalid_option
    assert_raise_with_message(ArgumentError, "invalid rounding mode (upp)") do
      BigDecimal('12.5').round(half: :upp)
    end
    assert_raise_with_message(ArgumentError, "invalid rounding mode (evenn)") do
      BigDecimal('2.15').round(1, half: :evenn)
    end
    assert_raise_with_message(ArgumentError, "invalid rounding mode (downn)") do
      BigDecimal('2.15').round(1, half: :downn)
    end
    assert_raise_with_message(ArgumentError, "invalid rounding mode (42)") do
      BigDecimal('2.15').round(1, half: 42)
    end
  end

  def test_truncate
    assert_equal(3, BigDecimal("3.14159").truncate)
    assert_equal(8, BigDecimal("8.7").truncate)
    assert_equal(3.141, BigDecimal("3.14159").truncate(3))
    assert_equal(13300.0, BigDecimal("13345.234").truncate(-2))

    assert_equal(-3, BigDecimal("-3.14159").truncate)
    assert_equal(-8, BigDecimal("-8.7").truncate)
    assert_equal(-3.141, BigDecimal("-3.14159").truncate(3))
    assert_equal(-13300.0, BigDecimal("-13345.234").truncate(-2))
  end

  def test_floor
    assert_equal(3, BigDecimal("3.14159").floor)
    assert_equal(-10, BigDecimal("-9.1").floor)
    assert_equal(3.141, BigDecimal("3.14159").floor(3))
    assert_equal(13300.0, BigDecimal("13345.234").floor(-2))
  end

  def test_ceil
    assert_equal(4, BigDecimal("3.14159").ceil)
    assert_equal(-9, BigDecimal("-9.1").ceil)
    assert_equal(3.142, BigDecimal("3.14159").ceil(3))
    assert_equal(13400.0, BigDecimal("13345.234").ceil(-2))
  end

  def test_to_s
    assert_equal('0.0', BigDecimal('0').to_s)
    assert_equal('-123 45678 90123.45678 90123 45678 9', BigDecimal('-1234567890123.45678901234567890').to_s('5F'))
    assert_equal('+12345 67890123.45678901 23456789', BigDecimal('1234567890123.45678901234567890').to_s('+8F'))
    assert_equal(' 1234567890123.4567890123456789', BigDecimal('1234567890123.45678901234567890').to_s(' F'))
    assert_equal('100 000 000 000.000 000 000 01', BigDecimal('100000000000.00000000001').to_s('3F'))
    assert_equal('0.0 0 0 0 0 0 0 0 0 0 0 0 1', BigDecimal('0.0000000000001').to_s('1F'))
    assert_equal('+1000000 0000000.0', BigDecimal('10000000000000').to_s('+7F'))
    assert_equal('0.1234567890123456789e3', BigDecimal('123.45678901234567890').to_s)
    assert_equal('0.12345 67890 12345 6789e3', BigDecimal('123.45678901234567890').to_s(5))
    assert_equal('0.123456 789012 345678e3', BigDecimal('123.456789012345678').to_s(6))
    assert_equal('0.123456 789012 345678 9e3', BigDecimal('123.4567890123456789').to_s(6))
  end

  def test_split
    x = BigDecimal('-123.45678901234567890')
    assert_equal([-1, "1234567890123456789", 10, 3], x.split)
    assert_equal([1, "0", 10, 0], BigDecimal("0").split)
    assert_equal([-1, "0", 10, 0], BigDecimal("-0").split)

    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
    assert_equal([0, "NaN", 10, 0], BigDecimal("NaN").split)
    assert_equal([1, "Infinity", 10, 0], BigDecimal("Infinity").split)
    assert_equal([-1, "Infinity", 10, 0], BigDecimal("-Infinity").split)
  end

  def test_exponent
    x = BigDecimal('-123.45678901234567890')
    assert_equal(3, x.exponent)
  end

  def test_inspect
    assert_equal("0.123456789012e0", BigDecimal("0.123456789012").inspect)
    assert_equal("0.123456789012e4", BigDecimal("1234.56789012").inspect)
    assert_equal("0.123456789012e-4", BigDecimal("0.0000123456789012").inspect)
    # Frac part is fully packed, exponent is minimum multiple of BASE_FIG
    s = "-0.#{'1' * BASE_FIG}e#{(EXPONENT_MIN / BASE_FIG + 1) * BASE_FIG}"
    assert_equal(s, BigDecimal(s).inspect)
  end

  def test_power
    assert_nothing_raised(TypeError, '[ruby-core:47632]') do
      1000.times { BigDecimal('1001.10')**0.75 }
    end
  end

  def test_power_with_nil
    assert_raise(TypeError) do
      BigDecimal(3) ** nil
    end
  end

  def test_power_of_nan
    assert_nan_calculation { BigDecimal::NAN ** 0 }
    assert_nan_calculation { BigDecimal::NAN ** 1 }
    assert_nan_calculation { BigDecimal::NAN ** 42 }
    assert_nan_calculation { BigDecimal::NAN ** -42 }
    assert_nan_calculation { BigDecimal::NAN ** 42.0 }
    assert_nan_calculation { BigDecimal::NAN ** -42.0 }
    assert_nan_calculation { BigDecimal::NAN ** BigDecimal(42) }
    assert_nan_calculation { BigDecimal::NAN ** BigDecimal(-42) }
    assert_nan_calculation { BigDecimal::NAN ** BigDecimal::INFINITY }
    assert_nan_calculation { BigDecimal::NAN ** NEGATIVE_INFINITY }
  end

  def test_power_with_Bignum
    assert_equal(0, BigDecimal(0) ** (2**100))

    assert_positive_infinite_calculation { BigDecimal(0) ** -(2**100) }
    assert_positive_infinite_calculation { BigDecimal(0) ** -(2**100 + 1) }
    assert_positive_infinite_calculation { (-BigDecimal(0)) ** -(2**100) }
    assert_negative_infinite_calculation { (-BigDecimal(0)) ** -(2**100 + 1) }

    assert_equal(1, BigDecimal(1) ** (2**100))
    assert_equal(1, BigDecimal(-1) ** (2**100))
    assert_equal(1, BigDecimal(1) ** (2**100 + 1))
    assert_equal(-1, BigDecimal(-1) ** (2**100 + 1))

    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
      BigDecimal.mode(BigDecimal::EXCEPTION_UNDERFLOW, false)
      # TODO: Add test and implementation for underflow and overflow errors

      assert_positive_infinite(BigDecimal(3) ** (2**100))
      assert_positive_zero(BigDecimal(3) ** (-2**100))

      assert_positive_infinite(BigDecimal(-3) ** (2**100))
      assert_negative_infinite(BigDecimal(-3) ** (2**100 + 1))
      assert_positive_zero(BigDecimal(-3) ** (-2**100))
      assert_negative_zero(BigDecimal(-3) ** (-2**100 - 1))

      assert_positive_zero(BigDecimal(0.5, Float::DIG) ** (2**100))
      assert_positive_infinite(BigDecimal(0.5, Float::DIG) ** (-2**100))

      assert_positive_zero(BigDecimal(-0.5, Float::DIG) ** (2**100))
      assert_negative_zero(BigDecimal(-0.5, Float::DIG) ** (2**100 - 1))
      assert_positive_infinite(BigDecimal(-0.5, Float::DIG) ** (-2**100))
      assert_negative_infinite(BigDecimal(-0.5, Float::DIG) ** (-2**100 - 1))
    end
  end

  def test_power_with_intger_infinite_precision
    assert_equal(1234 ** 100, (BigDecimal("12.34") ** 100) * BigDecimal("1e200"))
    assert_in_delta(1234 ** 100, 1 / (BigDecimal("12.34") ** -100) * BigDecimal("1e200"), 1)
  end

  def test_power_with_BigDecimal
    assert_nothing_raised do
      assert_in_delta(3 ** 3, BigDecimal(3) ** BigDecimal(3))
    end
  end

  def test_power_of_finite_with_zero
    x = BigDecimal(1)
    assert_equal(1, x ** 0)
    assert_equal(1, x ** 0.quo(1))
    assert_equal(1, x ** 0.0)
    assert_equal(1, x ** BigDecimal(0))

    x = BigDecimal(42)
    assert_equal(1, x ** 0)
    assert_equal(1, x ** 0.quo(1))
    assert_equal(1, x ** 0.0)
    assert_equal(1, x ** BigDecimal(0))

    x = BigDecimal(-42)
    assert_equal(1, x ** 0)
    assert_equal(1, x ** 0.quo(1))
    assert_equal(1, x ** 0.0)
    assert_equal(1, x ** BigDecimal(0))
  end

  def test_power_of_three
    x = BigDecimal(3)
    assert_equal(81, x ** 4)
    assert_in_delta(1.quo(81), x ** -4, 1e-32)
  end

  def test_power_of_zero
    zero = BigDecimal(0)
    assert_equal(0, zero ** 4)
    assert_equal(0, zero ** 4.quo(1))
    assert_equal(0, zero ** 4.0)
    assert_equal(0, zero ** BigDecimal(4))
    assert_equal(1, zero ** 0)
    assert_equal(1, zero ** 0.quo(1))
    assert_equal(1, zero ** 0.0)
    assert_equal(1, zero ** BigDecimal(0))

    assert_positive_infinite_calculation { zero ** -1 }
    assert_positive_infinite_calculation { zero ** -1.quo(1) }
    assert_positive_infinite_calculation { zero ** -1.0 }
    assert_positive_infinite_calculation { zero ** BigDecimal(-1) }

    m_zero = BigDecimal("-0")
    assert_negative_infinite_calculation { m_zero ** -1 }
    assert_negative_infinite_calculation { m_zero ** -1.quo(1) }
    assert_negative_infinite_calculation { m_zero ** -1.0 }
    assert_negative_infinite_calculation { m_zero ** BigDecimal(-1) }
    assert_positive_infinite_calculation { m_zero ** -2 }
    assert_positive_infinite_calculation { m_zero ** -2.quo(1) }
    assert_positive_infinite_calculation { m_zero ** -2.0 }
    assert_positive_infinite_calculation { m_zero ** BigDecimal(-2) }
  end

  def test_power_of_positive_infinity
    assert_positive_infinite_calculation { BigDecimal::INFINITY ** 3 }
    assert_positive_infinite_calculation { BigDecimal::INFINITY ** 3.quo(1) }
    assert_positive_infinite_calculation { BigDecimal::INFINITY ** 3.0 }
    assert_positive_infinite_calculation { BigDecimal::INFINITY ** BigDecimal(3) }
    assert_positive_infinite_calculation { BigDecimal::INFINITY ** 2 }
    assert_positive_infinite_calculation { BigDecimal::INFINITY ** 2.quo(1) }
    assert_positive_infinite_calculation { BigDecimal::INFINITY ** 2.0 }
    assert_positive_infinite_calculation { BigDecimal::INFINITY ** BigDecimal(2) }
    assert_positive_infinite_calculation { BigDecimal::INFINITY ** 1 }
    assert_positive_infinite_calculation { BigDecimal::INFINITY ** 1.quo(1) }
    assert_positive_infinite_calculation { BigDecimal::INFINITY ** 1.0 }
    assert_positive_infinite_calculation { BigDecimal::INFINITY ** BigDecimal(1) }
    assert_equal(1, BigDecimal::INFINITY ** 0)
    assert_equal(1, BigDecimal::INFINITY ** 0.quo(1))
    assert_equal(1, BigDecimal::INFINITY ** 0.0)
    assert_equal(1, BigDecimal::INFINITY ** BigDecimal(0))
    assert_positive_zero(BigDecimal::INFINITY ** -1)
    assert_positive_zero(BigDecimal::INFINITY ** -1.quo(1))
    assert_positive_zero(BigDecimal::INFINITY ** -1.0)
    assert_positive_zero(BigDecimal::INFINITY ** BigDecimal(-1))
    assert_positive_zero(BigDecimal::INFINITY ** -2)
    assert_positive_zero(BigDecimal::INFINITY ** -2.0)
    assert_positive_zero(BigDecimal::INFINITY ** BigDecimal(-2))
  end

  def test_power_of_negative_infinity
    assert_negative_infinite_calculation { NEGATIVE_INFINITY ** 3 }
    assert_negative_infinite_calculation { NEGATIVE_INFINITY ** 3.quo(1) }
    assert_negative_infinite_calculation { NEGATIVE_INFINITY ** 3.0 }
    assert_negative_infinite_calculation { NEGATIVE_INFINITY ** BigDecimal(3) }
    assert_positive_infinite_calculation { NEGATIVE_INFINITY ** 2 }
    assert_positive_infinite_calculation { NEGATIVE_INFINITY ** 2.quo(1) }
    assert_positive_infinite_calculation { NEGATIVE_INFINITY ** 2.0 }
    assert_positive_infinite_calculation { NEGATIVE_INFINITY ** BigDecimal(2) }
    assert_negative_infinite_calculation { NEGATIVE_INFINITY ** 1 }
    assert_negative_infinite_calculation { NEGATIVE_INFINITY ** 1.quo(1) }
    assert_negative_infinite_calculation { NEGATIVE_INFINITY ** 1.0 }
    assert_negative_infinite_calculation { NEGATIVE_INFINITY ** BigDecimal(1) }
    assert_equal(1, NEGATIVE_INFINITY ** 0)
    assert_equal(1, NEGATIVE_INFINITY ** 0.quo(1))
    assert_equal(1, NEGATIVE_INFINITY ** 0.0)
    assert_equal(1, NEGATIVE_INFINITY ** BigDecimal(0))
    assert_negative_zero(NEGATIVE_INFINITY ** -1)
    assert_negative_zero(NEGATIVE_INFINITY ** -1.quo(1))
    assert_negative_zero(NEGATIVE_INFINITY ** -1.0)
    assert_negative_zero(NEGATIVE_INFINITY ** BigDecimal(-1))
    assert_positive_zero(NEGATIVE_INFINITY ** -2)
    assert_positive_zero(NEGATIVE_INFINITY ** -2.quo(1))
    assert_positive_zero(NEGATIVE_INFINITY ** -2.0)
    assert_positive_zero(NEGATIVE_INFINITY ** BigDecimal(-2))
  end

  def test_infinite_power
    assert_positive_infinite_calculation { BigDecimal::INFINITY ** BigDecimal::INFINITY }
    assert_positive_zero(BigDecimal::INFINITY ** NEGATIVE_INFINITY)
    assert_positive_infinite_calculation { BigDecimal(3) ** BigDecimal::INFINITY }
    assert_positive_zero(BigDecimal(3) ** NEGATIVE_INFINITY)
    assert_positive_zero(BigDecimal("0.5") ** BigDecimal::INFINITY)
    assert_positive_infinite_calculation { BigDecimal("0.5") ** NEGATIVE_INFINITY }
    assert_equal(1, BigDecimal(1) ** BigDecimal::INFINITY)
    assert_equal(1, BigDecimal(1) ** NEGATIVE_INFINITY)
    assert_positive_zero(BigDecimal(0) ** BigDecimal::INFINITY)
    assert_positive_infinite_calculation { BigDecimal(0) ** NEGATIVE_INFINITY }
    assert_positive_zero(BigDecimal(-0.0) ** BigDecimal::INFINITY)
    assert_positive_infinite_calculation { BigDecimal(-0.0) ** NEGATIVE_INFINITY }

    # negative_number ** infinite_number converge to zero
    assert_positive_zero(BigDecimal(-2) ** NEGATIVE_INFINITY)
    assert_positive_zero(BigDecimal(-0.5) ** BigDecimal::INFINITY)
    assert_positive_zero(NEGATIVE_INFINITY ** NEGATIVE_INFINITY)

    # negative_number ** infinite_number that does not converge
    assert_raise(Math::DomainError) { BigDecimal(-2) ** BigDecimal::INFINITY }
    assert_raise(Math::DomainError) { BigDecimal(-0.5) ** NEGATIVE_INFINITY }
    assert_raise(Math::DomainError) { BigDecimal(-1) ** BigDecimal::INFINITY }
    assert_raise(Math::DomainError) { BigDecimal(-1) ** NEGATIVE_INFINITY }
    assert_raise(Math::DomainError) { NEGATIVE_INFINITY ** BigDecimal::INFINITY }
  end

  def test_power_without_prec
    pi  = BigDecimal("3.14159265358979323846264338327950288419716939937511")
    e   = BigDecimal("2.71828182845904523536028747135266249775724709369996")
    pow = BigDecimal("0.2245915771836104547342715220454373502758931513399678438732330680117e2")
    assert_equal(pow, pi.power(e))

    n = BigDecimal("2222")
    assert_equal(BigDecimal("0.51713530845725258924924158304123e12"), (n ** 3.5))
    assert_equal(BigDecimal("0.51713530845725258924924158304123e12"), (n ** 3.5r))
    assert_equal(BigDecimal("0.51713530845725258924924158304123e12"), (n ** BigDecimal("3.5", 100)))
  end

  def test_power_with_prec
    pi  = BigDecimal("3.14159265358979323846264338327950288419716939937511")
    e   = BigDecimal("2.71828182845904523536028747135266249775724709369996")
    pow = BigDecimal("22.459157718361045473")
    assert_equal(pow, pi.power(e, 20))

    b = BigDecimal('1.034482758620689655172413793103448275862068965517241379310344827586206896551724')
    assert_equal(BigDecimal('0.11452E1'), b.power(4, 5), '[Bug #8818] [ruby-core:56802]')

    assert_equal(BigDecimal('0.5394221232e-7'), BigDecimal('0.12345').power(8, 10))
  end

  def test_power_with_rational
    x1 = BigDecimal(2)
    x2 = BigDecimal('1.' + '1' * 100)
    y = 3 / 7r
    z1 = x1.power(BigDecimal(y, 100), 100)
    z2 = x2.power(BigDecimal(y, 100), 100)
    assert_in_epsilon(z1, x1.power(y, 100), 1e-99)
    assert_in_epsilon(z1, x1.power(y), 1e-30)
    assert_in_epsilon(z1, x1 ** y, 1e-30)
    assert_in_epsilon(z2, x2.power(y), 1e-99)
    assert_in_epsilon(z2, x2 ** y, 1e-99)
  end

  def test_power_precision
    x = BigDecimal("1.41421356237309504880168872420969807856967187537695")
    y = BigDecimal("3.14159265358979323846264338327950288419716939937511")
    small = x * BigDecimal("1e-30")
    large = y * BigDecimal("1e+30")
    assert_relative_precision {|n| small.power(small, n) }
    assert_relative_precision {|n| large.power(small, n) }
    assert_relative_precision {|n| x.power(small, n) }
    assert_relative_precision {|n| small.power(y, n) }
    assert_relative_precision {|n| small.power(small + 1, n) }
    assert_relative_precision {|n| x.power(small + 1, n) }
    assert_relative_precision {|n| (small + 1).power(small, n) }
    assert_relative_precision {|n| (small + 1).power(large, n) }
    assert_relative_precision {|n| (small + 1).power(y, n) }
    assert_relative_precision {|n| x.power(y, n) }
    assert_relative_precision {|n| x.power(-y, n) }
    assert_relative_precision {|n| x.power(123, n) }
    assert_relative_precision {|n| x.power(-456, n) }
    assert_relative_precision {|n| (x + 12).power(y + 34, n) }
    assert_relative_precision {|n| (x + 56).power(y - 78, n) }
  end

  def test_limit
    BigDecimal.save_limit do
      BigDecimal.limit(1)
      x = BigDecimal("3")
      assert_equal(80, x ** 4)
      assert_raise(ArgumentError) { BigDecimal.limit(-1) }

      bug7458 = '[ruby-core:50269] [#7458]'
      one = BigDecimal('1')
      epsilon = BigDecimal('0.7E-18')

      BigDecimal.limit(0)
      assert_equal(BigDecimal("1.0000000000000000007"), one + epsilon, "limit(0) #{bug7458}")

      1.upto(18) do |lim|
        BigDecimal.limit(lim)
        assert_equal(BigDecimal("1.0"), one + epsilon, "limit(#{lim}) #{bug7458}")
      end

      BigDecimal.limit(19)
      assert_equal(BigDecimal("1.000000000000000001"), one + epsilon, "limit(19) #{bug7458}")

      BigDecimal.limit(20)
      assert_equal(BigDecimal("1.0000000000000000007"), one + epsilon, "limit(20) #{bug7458}")
    end
  end

  def test_arithmetic_operation_with_limit
    BigDecimal.save_limit do
      BigDecimal.limit(3)
      assert_equal(BigDecimal('0.889'), (BigDecimal('0.8888') + BigDecimal('0')))
      assert_equal(BigDecimal('0.889'), (BigDecimal('0.8888') - BigDecimal('0')))
      assert_equal(BigDecimal('2.66'), (BigDecimal('0.888') * BigDecimal('3')))
      assert_equal(BigDecimal('0.296'), (BigDecimal('0.8888') / BigDecimal('3')))
      assert_equal(BigDecimal('0.889'), BigDecimal('0.8888').add(BigDecimal('0'), 0))
      assert_equal(BigDecimal('0.889'), BigDecimal('0.8888').sub(BigDecimal('0'), 0))
      assert_equal(BigDecimal('2.66'), BigDecimal('0.888').mult(BigDecimal('3'), 0))
      assert_equal(BigDecimal('0.296'), BigDecimal('0.8888').div(BigDecimal('3'), 0))
      assert_equal(BigDecimal('0.8888'), BigDecimal('0.8888').add(BigDecimal('0'), 5))
      assert_equal(BigDecimal('0.8888'), BigDecimal('0.8888').sub(BigDecimal('0'), 5))
      assert_equal(BigDecimal('2.664'), BigDecimal('0.888').mult(BigDecimal('3'), 5))
      assert_equal(BigDecimal('0.29627'), BigDecimal('0.8888').div(BigDecimal('3'), 5))
    end
  end

  def test_sign
    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_ZERODIVIDE, false)

    assert_equal(BigDecimal::SIGN_POSITIVE_ZERO, BigDecimal("0").sign)
    assert_equal(BigDecimal::SIGN_NEGATIVE_ZERO, BigDecimal("-0").sign)
    assert_equal(BigDecimal::SIGN_POSITIVE_FINITE, BigDecimal("1").sign)
    assert_equal(BigDecimal::SIGN_NEGATIVE_FINITE, BigDecimal("-1").sign)
    assert_equal(BigDecimal::SIGN_POSITIVE_INFINITE, (BigDecimal("1") / 0).sign)
    assert_equal(BigDecimal::SIGN_NEGATIVE_INFINITE, (BigDecimal("-1") / 0).sign)
    assert_equal(BigDecimal::SIGN_NaN, (BigDecimal("0") / 0).sign)
  end

  def test_inf
    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
    inf = BigDecimal("Infinity")

    assert_equal(inf, inf + inf)
    assert_nan((inf + (-inf)))
    assert_nan((inf - inf))
    assert_equal(inf, inf - (-inf))
    assert_equal(inf, inf * inf)
    assert_nan((inf / inf))

    assert_equal(inf, inf + 1)
    assert_equal(inf, inf - 1)
    assert_equal(inf, inf * 1)
    assert_nan((inf * 0))
    assert_equal(inf, inf / 1)

    assert_equal(inf, 1 + inf)
    assert_equal(-inf, 1 - inf)
    assert_equal(inf, 1 * inf)
    assert_equal(-inf, -1 * inf)
    assert_nan((0 * inf))
    assert_equal(BigDecimal::SIGN_POSITIVE_ZERO, (1 / inf).sign)
    assert_equal(BigDecimal::SIGN_NEGATIVE_ZERO, (-1 / inf).sign)
  end

  def assert_equal_us_ascii_string(a, b)
    assert_equal(a, b)
    assert_equal(Encoding::US_ASCII, b.encoding)
  end

  def test_to_special_string
    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
    BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
    nan = BigDecimal("NaN")
    assert_equal_us_ascii_string("NaN", nan.to_s)
    inf = BigDecimal("Infinity")
    assert_equal_us_ascii_string("Infinity", inf.to_s)
    assert_equal_us_ascii_string(" Infinity", inf.to_s(" "))
    assert_equal_us_ascii_string("+Infinity", inf.to_s("+"))
    assert_equal_us_ascii_string("-Infinity", (-inf).to_s)
    pzero = BigDecimal("0")
    assert_equal_us_ascii_string("0.0", pzero.to_s)
    assert_equal_us_ascii_string(" 0.0", pzero.to_s(" "))
    assert_equal_us_ascii_string("+0.0", pzero.to_s("+"))
    assert_equal_us_ascii_string("-0.0", (-pzero).to_s)
  end

  def test_to_string
    assert_equal_us_ascii_string("0.01", BigDecimal("0.01").to_s("F"))
    s = "0." + "0" * 100 + "1"
    assert_equal_us_ascii_string(s, BigDecimal(s).to_s("F"))
    s = "1" + "0" * 100 + ".0"
    assert_equal_us_ascii_string(s, BigDecimal(s).to_s("F"))
  end

  def test_ctov
    assert_equal(0.1, BigDecimal("1E-1"))
    assert_equal(10, BigDecimal("1E+1"))
    assert_equal(1, BigDecimal("+1"))
    BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)

    assert_equal(BigDecimal::SIGN_POSITIVE_INFINITE, BigDecimal("1E1" + "0" * 10000).sign)
    assert_equal(BigDecimal::SIGN_NEGATIVE_INFINITE, BigDecimal("-1E1" + "0" * 10000).sign)
    assert_equal(BigDecimal::SIGN_POSITIVE_ZERO, BigDecimal("1E-1" + "0" * 10000).sign)
    assert_equal(BigDecimal::SIGN_NEGATIVE_ZERO, BigDecimal("-1E-1" + "0" * 10000).sign)
  end

  def test_split_under_gc_stress
    bug3258 = '[ruby-dev:41213]'
    expect = 10.upto(20).map{|i|[1, "1", 10, i+1].inspect}
    paths = $LOAD_PATH.map{|path| "-I#{path}" }
    assert_in_out_err([*paths, "-rbigdecimal", "--disable-gems"], <<-EOS, expect, [], bug3258)
    GC.stress = true
    10.upto(20) do |i|
      p BigDecimal("1"+"0"*i).split
    end
    EOS
  end

  def test_coerce_under_gc_stress
    paths = $LOAD_PATH.map{|path| "-I#{path}" }
    assert_in_out_err([*paths, "-rbigdecimal", "--disable-gems"], <<-EOS, [], [])
      expect = ":too_long_to_embed_as_string can't be coerced into BigDecimal"
      b = BigDecimal("1")
      GC.stress = true
      10.times do
        begin
          b.coerce(:too_long_to_embed_as_string)
        rescue => e
          raise unless e.is_a?(TypeError)
          raise "'\#{expect}' is expected, but '\#{e.message}'" unless e.message == expect
        end
      end
    EOS
  end

  def test_INFINITY
    assert_positive_infinite(BigDecimal::INFINITY)
  end

  def test_NAN
    assert_nan(BigDecimal::NAN)
  end

  def test_exp_with_zero_precision
    assert_raise(ArgumentError) do
      BigMath.exp(1, 0)
    end
  end

  def test_exp_with_negative_precision
    assert_raise(ArgumentError) do
      BigMath.exp(1, -42)
    end
  end

  def test_exp_with_complex
    assert_raise(ArgumentError) do
      BigMath.exp(Complex(1, 2), 20)
    end
  end

  def test_exp_with_negative
    x = BigDecimal(-1)
    y = BigMath.exp(x, 20)
    assert_equal(y, BigMath.exp(-1, 20))
    assert_equal(BigDecimal(-1), x)
  end

  def test_exp_with_negative_infinite
    assert_equal(0, BigMath.exp(NEGATIVE_INFINITY, 20))
  end

  def test_exp_with_positive_infinite
    assert_positive_infinite_calculation { BigMath.exp(BigDecimal::INFINITY, 20) }
  end

  def test_exp_with_nan
    assert_nan_calculation { BigMath.exp(BigDecimal::NAN, 20) }
  end

  def test_exp_with_1
    assert_in_epsilon(Math::E, BigMath.exp(1, 20))
  end

  def test_BigMath_exp
    prec = 20
    assert_in_epsilon(Math.exp(20), BigMath.exp(BigDecimal("20"), prec))
    assert_in_epsilon(Math.exp(40), BigMath.exp(BigDecimal("40"), prec))
    assert_in_epsilon(Math.exp(-20), BigMath.exp(BigDecimal("-20"), prec))
    assert_in_epsilon(Math.exp(-40), BigMath.exp(BigDecimal("-40"), prec))
  end

  def test_BigMath_exp_with_float
    prec = 20
    assert_in_epsilon(Math.exp(20), BigMath.exp(20.0, prec))
    assert_in_epsilon(Math.exp(40), BigMath.exp(40.0, prec))
    assert_in_epsilon(Math.exp(-20), BigMath.exp(-20.0, prec))
    assert_in_epsilon(Math.exp(-40), BigMath.exp(-40.0, prec))
  end

  def test_BigMath_exp_with_fixnum
    prec = 20
    assert_in_epsilon(Math.exp(20), BigMath.exp(20, prec))
    assert_in_epsilon(Math.exp(40), BigMath.exp(40, prec))
    assert_in_epsilon(Math.exp(-20), BigMath.exp(-20, prec))
    assert_in_epsilon(Math.exp(-40), BigMath.exp(-40, prec))
  end

  def test_BigMath_exp_with_rational
    prec = 20
    assert_in_epsilon(Math.exp(20), BigMath.exp(Rational(40,2), prec))
    assert_in_epsilon(Math.exp(40), BigMath.exp(Rational(80,2), prec))
    assert_in_epsilon(Math.exp(-20), BigMath.exp(Rational(-40,2), prec))
    assert_in_epsilon(Math.exp(-40), BigMath.exp(Rational(-80,2), prec))
    assert_in_epsilon(BigMath.exp(BigDecimal(3 / 7r, 100), 100), BigMath.exp(3 / 7r, 100), 1e-99)
  end

  def test_BigMath_exp_under_gc_stress
    paths = $LOAD_PATH.map{|path| "-I#{path}" }
    assert_in_out_err([*paths, "-rbigdecimal", "--disable-gems"], <<-EOS, [], [])
      expect = ":too_long_to_embed_as_string can't be coerced into BigDecimal"
      10.times do
        begin
          BigMath.exp(:too_long_to_embed_as_string, 6)
        rescue => e
          raise unless e.is_a?(ArgumentError)
          raise "'\#{expect}' is expected, but '\#{e.message}'" unless e.message == expect
        end
      end
    EOS
  end

  def test_BigMath_log_with_string
    assert_raise(ArgumentError) do
      BigMath.log("foo", 20)
    end
  end

  def test_BigMath_log_with_nil
    assert_raise(ArgumentError) do
      BigMath.log(nil, 20)
    end
  end

  def test_BigMath_log_with_non_integer_precision
    assert_raise(ArgumentError) do
      BigMath.log(1, 0.5)
    end
  end

  def test_BigMath_log_with_nil_precision
    assert_raise(ArgumentError) do
      BigMath.log(1, nil)
    end
  end

  def test_BigMath_log_with_complex
    assert_raise(Math::DomainError) do
      BigMath.log(Complex(1, 2), 20)
    end
  end

  def test_BigMath_log_with_zero_arg
    assert_raise(Math::DomainError) do
      BigMath.log(0, 20)
    end
  end

  def test_BigMath_log_with_negative_arg
    assert_raise(Math::DomainError) do
      BigMath.log(-1, 20)
    end
  end

  def test_BigMath_log_with_zero_precision
    assert_raise(ArgumentError) do
      BigMath.log(1, 0)
    end
  end

  def test_BigMath_log_with_negative_precision
    assert_raise(ArgumentError) do
      BigMath.log(1, -42)
    end
  end

  def test_BigMath_log_with_negative_infinite
    assert_raise(Math::DomainError) do
      BigMath.log(NEGATIVE_INFINITY, 20)
    end
  end

  def test_BigMath_log_with_positive_infinite
    assert_positive_infinite_calculation { BigMath.log(BigDecimal::INFINITY, 20) }
  end

  def test_BigMath_log_with_nan
    assert_nan_calculation { BigMath.log(BigDecimal::NAN, 20) }
  end

  def test_BigMath_log_with_float_nan
    assert_nan_calculation { BigMath.log(Float::NAN, 20) }
  end

  def test_BigMath_log_with_1
    assert_in_delta(0.0, BigMath.log(1, 20))
    assert_in_delta(0.0, BigMath.log(1.0, 20))
    assert_in_delta(0.0, BigMath.log(BigDecimal(1), 20))
  end

  def test_BigMath_log_with_exp_1
    assert_in_delta(1.0, BigMath.log(BigMath.E(10), 10))
  end

  def test_BigMath_log_with_2
    assert_in_delta(Math.log(2), BigMath.log(2, 20))
    assert_in_delta(Math.log(2), BigMath.log(2.0, 20))
    assert_in_delta(Math.log(2), BigMath.log(BigDecimal(2), 20))
  end

  def test_BigMath_log_with_square_of_E
    assert_in_delta(2, BigMath.log(BigMath.E(20)**2, 20))
  end

  def test_BigMath_log_with_high_precision_case
    e   = BigDecimal('2.71828182845904523536028747135266249775724709369996')
    e_3 = e.mult(e, 50).mult(e, 50)
    log_3 = BigMath.log(e_3, 50)
    assert_in_delta(3, log_3, 0.0000000000_0000000000_0000000000_0000000000_0000000001)
  end

  def test_BigMath_log_with_42
    assert_in_delta(Math.log(42), BigMath.log(42, 20))
    assert_in_delta(Math.log(42), BigMath.log(42.0, 20))
    assert_in_delta(Math.log(42), BigMath.log(BigDecimal(42), 20))
  end

  def test_BigMath_log_with_101
    # this is mainly a performance test (should be very fast, not the 0.3 s)
    assert_in_delta(Math.log(101), BigMath.log(101, 20), 1E-15)
  end

  def test_BigMath_log_with_reciprocal_of_42
    assert_in_delta(Math.log(1e-42), BigMath.log(1e-42, 20))
    assert_in_delta(Math.log(1e-42), BigMath.log(BigDecimal("1e-42"), 20))
  end

  def test_BigMath_log_with_rational
    assert_in_epsilon(BigMath.log(BigDecimal(3 / 7r, 100), 100), BigMath.log(3 / 7r, 100), 1e-99)
  end

  def test_BigMath_log_under_gc_stress
    paths = $LOAD_PATH.map{|path| "-I#{path}" }
    assert_in_out_err([*paths, "-rbigdecimal", "--disable-gems"], <<-EOS, [], [])
      expect = ":too_long_to_embed_as_string can't be coerced into BigDecimal"
      10.times do
        begin
          BigMath.log(:too_long_to_embed_as_string, 6)
        rescue => e
          raise unless e.is_a?(ArgumentError)
          raise "'\#{expect}' is expected, but '\#{e.message}'" unless e.message == expect
        end
      end
    EOS
  end

  def test_frozen_p
    x = BigDecimal(1)
    assert(x.frozen?)
    assert((x + x).frozen?)
  end

  def test_clone
    assert_warning(/^$/) do
      x = BigDecimal(0)
      assert_same(x, x.clone)
    end
  end

  def test_dup
    assert_warning(/^$/) do
      [1, -1, 2**100, -2**100].each do |i|
        x = BigDecimal(i)
        assert_same(x, x.dup)
      end
    end
  end

  def test_new_subclass
    c = Class.new(BigDecimal)
    assert_raise_with_message(NoMethodError, /undefined method [`']new'/) { c.new(1) }
  end

  def test_bug6406
    paths = $LOAD_PATH.map{|path| "-I#{path}" }
    assert_in_out_err([*paths, "-rbigdecimal", "--disable-gems"], <<-EOS, [], [])
    Thread.current.keys.to_s
    EOS
  end

  def test_precision_only_integer
    assert_equal(0, BigDecimal(0).precision)
    assert_equal(1, BigDecimal(1).precision)
    assert_equal(1, BigDecimal(-1).precision)
    assert_equal(2, BigDecimal(10).precision)
    assert_equal(2, BigDecimal(-10).precision)
    assert_equal(9, BigDecimal(100_000_000).precision)
    assert_equal(9, BigDecimal(-100_000_000).precision)
    assert_equal(12, BigDecimal(100_000_000_000).precision)
    assert_equal(12, BigDecimal(-100_000_000_000).precision)
    assert_equal(21, BigDecimal(100_000_000_000_000_000_000).precision)
    assert_equal(21, BigDecimal(-100_000_000_000_000_000_000).precision)
    assert_equal(103, BigDecimal("111e100").precision)
    assert_equal(103, BigDecimal("-111e100").precision)
  end

  def test_precision_only_fraction
    assert_equal(1, BigDecimal("0.1").precision)
    assert_equal(1, BigDecimal("-0.1").precision)
    assert_equal(2, BigDecimal("0.01").precision)
    assert_equal(2, BigDecimal("-0.01").precision)
    assert_equal(2, BigDecimal("0.11").precision)
    assert_equal(2, BigDecimal("-0.11").precision)
    assert_equal(9, BigDecimal("0.000_000_001").precision)
    assert_equal(9, BigDecimal("-0.000_000_001").precision)
    assert_equal(10, BigDecimal("0.000_000_000_1").precision)
    assert_equal(10, BigDecimal("-0.000_000_000_1").precision)
    assert_equal(21, BigDecimal("0.000_000_000_000_000_000_001").precision)
    assert_equal(21, BigDecimal("-0.000_000_000_000_000_000_001").precision)
    assert_equal(100, BigDecimal("111e-100").precision)
    assert_equal(100, BigDecimal("-111e-100").precision)
  end

  def test_precision_full
    assert_equal(5, BigDecimal("11111e-2").precision)
    assert_equal(5, BigDecimal("-11111e-2").precision)
    assert_equal(5, BigDecimal("11111e-2").precision)
    assert_equal(5, BigDecimal("-11111e-2").precision)
    assert_equal(21, BigDecimal("100.000_000_000_000_000_001").precision)
    assert_equal(21, BigDecimal("-100.000_000_000_000_000_001").precision)
  end

  def test_precision_special
    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
      BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)

      assert_equal(0, BigDecimal("Infinity").precision)
      assert_equal(0, BigDecimal("-Infinity").precision)
      assert_equal(0, BigDecimal("NaN").precision)
    end
  end

  def test_scale_only_integer
    assert_equal(0, BigDecimal(0).scale)
    assert_equal(0, BigDecimal(1).scale)
    assert_equal(0, BigDecimal(-1).scale)
    assert_equal(0, BigDecimal(10).scale)
    assert_equal(0, BigDecimal(-10).scale)
    assert_equal(0, BigDecimal(100_000_000).scale)
    assert_equal(0, BigDecimal(-100_000_000).scale)
    assert_equal(0, BigDecimal(100_000_000_000).scale)
    assert_equal(0, BigDecimal(-100_000_000_000).scale)
    assert_equal(0, BigDecimal(100_000_000_000_000_000_000).scale)
    assert_equal(0, BigDecimal(-100_000_000_000_000_000_000).scale)
    assert_equal(0, BigDecimal("111e100").scale)
    assert_equal(0, BigDecimal("-111e100").scale)
  end

  def test_scale_only_fraction
    assert_equal(1, BigDecimal("0.1").scale)
    assert_equal(1, BigDecimal("-0.1").scale)
    assert_equal(2, BigDecimal("0.01").scale)
    assert_equal(2, BigDecimal("-0.01").scale)
    assert_equal(2, BigDecimal("0.11").scale)
    assert_equal(2, BigDecimal("-0.11").scale)
    assert_equal(21, BigDecimal("0.000_000_000_000_000_000_001").scale)
    assert_equal(21, BigDecimal("-0.000_000_000_000_000_000_001").scale)
    assert_equal(100, BigDecimal("111e-100").scale)
    assert_equal(100, BigDecimal("-111e-100").scale)
  end

  def test_scale_full
    assert_equal(1, BigDecimal("0.1").scale)
    assert_equal(1, BigDecimal("-0.1").scale)
    assert_equal(2, BigDecimal("0.01").scale)
    assert_equal(2, BigDecimal("-0.01").scale)
    assert_equal(2, BigDecimal("0.11").scale)
    assert_equal(2, BigDecimal("-0.11").scale)
    assert_equal(2, BigDecimal("11111e-2").scale)
    assert_equal(2, BigDecimal("-11111e-2").scale)
    assert_equal(18, BigDecimal("100.000_000_000_000_000_001").scale)
    assert_equal(18, BigDecimal("-100.000_000_000_000_000_001").scale)
  end

  def test_scale_special
    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
      BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)

      assert_equal(0, BigDecimal("Infinity").scale)
      assert_equal(0, BigDecimal("-Infinity").scale)
      assert_equal(0, BigDecimal("NaN").scale)
    end
  end

  def test_precision_scale
    assert_equal([2, 0], BigDecimal("11.0").precision_scale)
    assert_equal([2, 1], BigDecimal("1.1").precision_scale)
    assert_equal([2, 2], BigDecimal("0.11").precision_scale)

    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
      assert_equal([0, 0], BigDecimal("Infinity").precision_scale)
    end
  end

  def test_n_significant_digits_only_integer
    assert_equal(0, BigDecimal(0).n_significant_digits)
    assert_equal(1, BigDecimal(1).n_significant_digits)
    assert_equal(1, BigDecimal(-1).n_significant_digits)
    assert_equal(1, BigDecimal(10).n_significant_digits)
    assert_equal(1, BigDecimal(-10).n_significant_digits)
    assert_equal(3, BigDecimal(101).n_significant_digits)
    assert_equal(3, BigDecimal(-101).n_significant_digits)
    assert_equal(1, BigDecimal(100_000_000_000_000_000_000).n_significant_digits)
    assert_equal(1, BigDecimal(-100_000_000_000_000_000_000).n_significant_digits)
    assert_equal(21, BigDecimal(100_000_000_000_000_000_001).n_significant_digits)
    assert_equal(21, BigDecimal(-100_000_000_000_000_000_001).n_significant_digits)
    assert_equal(3, BigDecimal("111e100").n_significant_digits)
    assert_equal(3, BigDecimal("-111e100").n_significant_digits)
  end

  def test_n_significant_digits_only_fraction
    assert_equal(1, BigDecimal("0.1").n_significant_digits)
    assert_equal(1, BigDecimal("-0.1").n_significant_digits)
    assert_equal(1, BigDecimal("0.01").n_significant_digits)
    assert_equal(1, BigDecimal("-0.01").n_significant_digits)
    assert_equal(2, BigDecimal("0.11").n_significant_digits)
    assert_equal(2, BigDecimal("-0.11").n_significant_digits)
    assert_equal(1, BigDecimal("0.000_000_000_000_000_000_001").n_significant_digits)
    assert_equal(1, BigDecimal("-0.000_000_000_000_000_000_001").n_significant_digits)
    assert_equal(3, BigDecimal("111e-100").n_significant_digits)
    assert_equal(3, BigDecimal("-111e-100").n_significant_digits)
  end

  def test_n_significant_digits_full
    assert_equal(2, BigDecimal("1.1").n_significant_digits)
    assert_equal(2, BigDecimal("-1.1").n_significant_digits)
    assert_equal(3, BigDecimal("1.01").n_significant_digits)
    assert_equal(3, BigDecimal("-1.01").n_significant_digits)
    assert_equal(5, BigDecimal("11111e-2").n_significant_digits)
    assert_equal(5, BigDecimal("-11111e-2").n_significant_digits)
    assert_equal(21, BigDecimal("100.000_000_000_000_000_001").n_significant_digits)
    assert_equal(21, BigDecimal("-100.000_000_000_000_000_001").n_significant_digits)
  end

  def test_n_significant_digits_special
    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_OVERFLOW, false)
      BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)

      assert_equal(0, BigDecimal("Infinity").n_significant_digits)
      assert_equal(0, BigDecimal("-Infinity").n_significant_digits)
      assert_equal(0, BigDecimal("NaN").n_significant_digits)
    end
  end

  def test_initialize_copy_dup_clone_frozen_error
    bd = BigDecimal(1)
    bd2 = BigDecimal(2)
    assert_raise(FrozenError) { bd.send(:initialize_copy, bd2) }
    assert_raise(FrozenError) { bd.send(:initialize_clone, bd2) }
    assert_raise(FrozenError) { bd.send(:initialize_dup, bd2) }
  end

  def test_llong_min_gh_200
    # https://github.com/ruby/bigdecimal/issues/199
    # Between LLONG_MIN and -ULLONG_MAX
    assert_equal(BigDecimal(LIMITS["LLONG_MIN"].to_s), BigDecimal(LIMITS["LLONG_MIN"]), "[GH-200]")

    minus_ullong_max = -LIMITS["ULLONG_MAX"]
    assert_equal(BigDecimal(minus_ullong_max.to_s), BigDecimal(minus_ullong_max), "[GH-200]")
  end

  def test_reminder_infinity_gh_187
    # https://github.com/ruby/bigdecimal/issues/187
    BigDecimal.save_exception_mode do
      BigDecimal.mode(BigDecimal::EXCEPTION_INFINITY, false)
      BigDecimal.mode(BigDecimal::EXCEPTION_NaN, false)
      bd = BigDecimal("4.2")
      assert_equal(bd.remainder(BigDecimal("+Infinity")), bd)
      assert_equal(bd.remainder(BigDecimal("-Infinity")), bd)
    end
  end

  def test_bsearch_for_bigdecimal
    assert_raise(TypeError) {
      (BigDecimal('0.5')..BigDecimal('2.25')).bsearch
    }
  end

  def test_gc_compaction_safe
    omit if RUBY_VERSION < "3.2" || RUBY_ENGINE == "truffleruby"

    assert_separately(["-rbigdecimal"], "#{<<~"begin;"}\n#{<<~'end;'}")
    begin;
      x = 1.5
      y = 0.5
      nan = BigDecimal("NaN")
      inf = BigDecimal("Infinity")
      bx = BigDecimal(x.to_s)
      by = BigDecimal(y.to_s)
      GC.verify_compaction_references(expand_heap: true, toward: :empty)

      assert_in_delta(x + y, bx + by)
      assert_in_delta(x + y, bx.add(by, 10))
      assert_in_delta(x - y, bx - by)
      assert_in_delta(x - y, bx.sub(by, 10))
      assert_in_delta(x * y, bx * by)
      assert_in_delta(x * y, bx.mult(by, 10))
      assert_in_delta(x / y, bx / by)
      assert_in_delta(x / y, bx.div(by, 10))
      assert_in_delta((x / y).floor, bx.div(by))
      assert_in_delta(x % y, bx % by)
      assert_in_delta(Math.sqrt(x), bx.sqrt(10))
      assert_equal(x.div(y), bx.div(by))
      assert_equal(x.remainder(y), bx.remainder(by))
      assert_equal(x.divmod(y), bx.divmod(by))
      assert_equal([0, x], bx.divmod(inf))
      assert_in_delta(x, bx.remainder(inf))
      assert((nan + nan).nan?)
      assert((nan - nan).nan?)
      assert((nan * nan).nan?)
      assert((nan / nan).nan?)
      assert((nan % nan).nan?)
      assert((inf + inf).infinite?)
      assert((inf - inf).nan?)
      assert((inf * inf).infinite?)
      assert((inf / inf).nan?)
      assert((inf % inf).nan?)
      assert_in_delta(Math.exp(x), BigMath.exp(bx, 10))
      assert_in_delta(x**y, bx**by)
      assert_in_delta(x**y, bx.power(by, 10))
      assert_in_delta(Math.exp(x), BigMath.exp(bx, 10))
      assert_in_delta(Math.log(x), BigMath.log(bx, 10))
    end;
  end

  def assert_no_memory_leak(code, *rest, **opt)
    code = "8.times {20_000.times {begin #{code}; rescue NoMemoryError; end}; GC.start}"
    paths = $LOAD_PATH.map{|path| "-I#{path}" }
    super([*paths, "-rbigdecimal"],
          "b = BigDecimal('10'); b.nil?; " \
          "GC.add_stress_to_class(BigDecimal); "\
          "#{code}", code, *rest, rss: true, limit: 1.1, **opt)
  end

  if EnvUtil.gc_stress_to_class?
    def test_no_memory_leak_BigDecimal
      assert_no_memory_leak("BigDecimal('10')")
      assert_no_memory_leak("BigDecimal(b)")
    end

    def test_no_memory_leak_create
      assert_no_memory_leak("b + 10")
    end
  end
end
