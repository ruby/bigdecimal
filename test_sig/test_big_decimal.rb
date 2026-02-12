require "bigdecimal"
require "bigdecimal/util"
require 'test/unit'
require 'rbs/unit_test'

class BigDecimalSingletonTest < Test::Unit::TestCase
  include TestHelper
  library "bigdecimal"
  testing "singleton(::BigDecimal)"

  def test__load
    assert_send_type "(::String) -> ::BigDecimal",
                     BigDecimal, :_load, "18:0.123e1"
  end

  def test_double_fig
    assert_send_type "() -> ::Integer",
                     BigDecimal, :double_fig
  end

  def test_interpret_loosely
    assert_send_type "(String) -> BigDecimal",
                     BigDecimal, :interpret_loosely, "1.23"
    assert_send_type "(_ToStr) -> BigDecimal",
                     BigDecimal, :interpret_loosely, ToStr.new("1.23")
  end

  def test_limit
    BigDecimal.save_limit do
      assert_send_type "() -> ::Integer",
                       BigDecimal, :limit
      assert_send_type "(nil) -> ::Integer",
                       BigDecimal, :limit, nil
      assert_send_type "(::Integer digits) -> ::Integer",
                       BigDecimal, :limit, 5
    end
  end

  def test_mode
    BigDecimal.save_exception_mode do
      assert_send_type "(::Integer mode) -> ::Integer",
                      BigDecimal, :mode, BigDecimal::EXCEPTION_ALL
      assert_send_type "(::Integer mode, true setting) -> ::Integer",
                      BigDecimal, :mode, BigDecimal::EXCEPTION_ALL, true
      assert_send_type "(::Integer mode, false setting) -> ::Integer",
                      BigDecimal, :mode, BigDecimal::EXCEPTION_ALL, false
      assert_send_type "(::Integer mode, nil setting) -> ::Integer",
                      BigDecimal, :mode, BigDecimal::EXCEPTION_ALL, nil
    end

    BigDecimal.save_rounding_mode do
      assert_send_type "(::Integer mode) -> ::Integer",
                      BigDecimal, :mode, BigDecimal::ROUND_MODE
      assert_send_type "(::Integer mode, ::Integer setting) -> ::Integer",
                      BigDecimal, :mode, BigDecimal::ROUND_MODE, BigDecimal::ROUND_DOWN
      assert_send_type "(::Integer mode, ::Symbol setting) -> ::Integer",
                      BigDecimal, :mode, BigDecimal::ROUND_MODE, :half_up
    end
  end

  # FIXME: 実装がブロックにnilを渡すため、型定義の() -> voidと一致しない
  def test_save_exception_mode
    assert_send_type "() { (nil) -> void } -> void",
                     BigDecimal, :save_exception_mode do end
  end

  def test_save_limit
    assert_send_type "() { (nil) -> void } -> void",
                     BigDecimal, :save_limit do end
  end

  def test_save_rounding_mode
    assert_send_type "() { (nil) -> void } -> void",
                     BigDecimal, :save_rounding_mode do end
  end

  def test_kernel
    assert_send_type "(::String) -> ::BigDecimal",
                     Kernel, :BigDecimal, "1.23"
    assert_send_type "(::_ToStr) -> ::BigDecimal",
                     Kernel, :BigDecimal, ToStr.new("1.23")
    assert_send_type "(::Integer) -> ::BigDecimal",
                     Kernel, :BigDecimal, 123
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     Kernel, :BigDecimal, BigDecimal("1.23")
    assert_send_type "(::Float, ::Integer) -> ::BigDecimal",
                     Kernel, :BigDecimal, 1.23, 1
    assert_send_type "(::Float, ::_ToInt) -> ::BigDecimal",
                     Kernel, :BigDecimal, 1.23, ToInt.new(1)
    assert_send_type "(::Rational, ::Integer) -> ::BigDecimal",
                     Kernel, :BigDecimal, Rational(1.23), 1
    assert_send_type "(::String, exception: bool) -> ::BigDecimal",
                     Kernel, :BigDecimal, "1.23", exception: false
    assert_send_type "(::Float, ::Integer, exception: bool) -> ::BigDecimal",
                     Kernel, :BigDecimal, 1.23, 1, exception: true
  end

  def test_constants
    assert_const_type 'Integer', 'BigDecimal::BASE'
    assert_const_type 'Integer', 'BigDecimal::EXCEPTION_ALL'
    assert_const_type 'Integer', 'BigDecimal::EXCEPTION_INFINITY'
    assert_const_type 'Integer', 'BigDecimal::EXCEPTION_NaN'
    assert_const_type 'Integer', 'BigDecimal::EXCEPTION_OVERFLOW'
    assert_const_type 'Integer', 'BigDecimal::EXCEPTION_UNDERFLOW'
    assert_const_type 'Integer', 'BigDecimal::EXCEPTION_ZERODIVIDE'
    assert_const_type 'BigDecimal', 'BigDecimal::INFINITY'
    assert_const_type 'BigDecimal', 'BigDecimal::NAN'
    assert_const_type 'Integer', 'BigDecimal::ROUND_CEILING'
    assert_const_type 'Integer', 'BigDecimal::ROUND_DOWN'
    assert_const_type 'Integer', 'BigDecimal::ROUND_FLOOR'
    assert_const_type 'Integer', 'BigDecimal::ROUND_HALF_DOWN'
    assert_const_type 'Integer', 'BigDecimal::ROUND_HALF_EVEN'
    assert_const_type 'Integer', 'BigDecimal::ROUND_HALF_UP'
    assert_const_type 'Integer', 'BigDecimal::ROUND_MODE'
    assert_const_type 'Integer', 'BigDecimal::ROUND_UP'
    assert_const_type 'Integer', 'BigDecimal::SIGN_NEGATIVE_FINITE'
    assert_const_type 'Integer', 'BigDecimal::SIGN_NEGATIVE_INFINITE'
    assert_const_type 'Integer', 'BigDecimal::SIGN_NEGATIVE_ZERO'
    assert_const_type 'Integer', 'BigDecimal::SIGN_NaN'
    assert_const_type 'Integer', 'BigDecimal::SIGN_POSITIVE_FINITE'
    assert_const_type 'Integer', 'BigDecimal::SIGN_POSITIVE_INFINITE'
    assert_const_type 'Integer', 'BigDecimal::SIGN_POSITIVE_ZERO'
    assert_const_type 'String', 'BigDecimal::VERSION'
  end
end

class BigDecimalTest < Test::Unit::TestCase
  include TestHelper
  library "bigdecimal"
  testing "::BigDecimal"

  def test_double_equal
    assert_send_type "(untyped) -> bool",
                     BigDecimal("1.23"), :==, BigDecimal("1.234")
  end

  def test_spaceship
    assert_send_type "(::Numeric) -> ::Integer?",
                     BigDecimal("1.23"), :<=>, BigDecimal("1.234")
  end

  def test_triple_equal
    assert_send_type "(untyped) -> bool",
                     BigDecimal("1.23"), :===, BigDecimal("1.234")
  end

  def test_clone
    assert_send_type "() -> BigDecimal",
                     BigDecimal("1.23"), :clone
  end

  def test_dup
    assert_send_type "() -> BigDecimal",
                     BigDecimal("1.23"), :dup
  end

  def test_eql?
    assert_send_type "(untyped) -> bool",
                     BigDecimal("1.23"), :eql?, BigDecimal("1.234")
  end

  def test_hash
    assert_send_type "() -> ::Integer",
                     BigDecimal("1.23"), :hash
  end

  def test_inspect
    assert_send_type "() -> ::String",
                     BigDecimal("1.23"), :inspect
  end

  def test_to_s
    assert_send_type "() -> ::String",
                     BigDecimal("1.23"), :to_s
    assert_send_type "(::String s) -> ::String",
                     BigDecimal("1.23"), :to_s, "2F"
    assert_send_type "(::int s) -> ::String",
                     BigDecimal("1.23"), :to_s, 2
  end

  def test_less_than
    assert_send_type "(::BigDecimal) -> bool",
                     BigDecimal("1.23"), :<, BigDecimal("1.234")
    with_real(1.234) do |real|
      assert_send_type "(::real) -> bool",
                       BigDecimal("1.23"), :<, real
    end
  end

  def test_less_than_equal_to
    assert_send_type "(::BigDecimal) -> bool",
                     BigDecimal("1.23"), :<=, BigDecimal("1.234")
    with_real(1.234) do |real|
      assert_send_type "(::real) -> bool",
                       BigDecimal("1.23"), :<=, real
    end
  end

  def test_greater_than
    assert_send_type "(::BigDecimal) -> bool",
                     BigDecimal("1.23"), :>, BigDecimal("1.234")
    with_real(1.234) do |real|
      assert_send_type "(::real) -> bool",
                       BigDecimal("1.23"), :>, real
    end
  end

  def test_greater_than_equal_to
    assert_send_type "(::BigDecimal) -> bool",
                     BigDecimal("1.23"), :>=, BigDecimal("1.234")
    with_real(1.234) do |real|
      assert_send_type "(::real) -> bool",
                       BigDecimal("1.23"), :>=, real
    end
  end

  def test_modulus
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     BigDecimal("1.23"), :%, BigDecimal("1.234")
    with_real(1.234) do |real|
      assert_send_type "(::real) -> ::BigDecimal",
                       BigDecimal("1.23"), :%, real
    end
  end

  def test_multiply
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     BigDecimal("2"), :*, BigDecimal("3")
    with_real(3) do |real|
      assert_send_type "(::real) -> ::BigDecimal",
                       BigDecimal("2"), :*, real
    end
    assert_send_type "(::Complex) -> ::Complex",
                     BigDecimal("2"), :*, Complex(1, 2)
  end

  def test_starstar
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     BigDecimal("2"), :**, BigDecimal("3")
    with_real(3) do |real|
      assert_send_type "(::real) -> ::BigDecimal",
                       BigDecimal("2"), :**, real
    end
    assert_send_type "(::Complex) -> ::Complex",
                     BigDecimal("2"), :**, Complex(1, 0)
  end

  def test_power
    with_real(2) do |real|
      assert_send_type "(::real) -> ::BigDecimal",
                       BigDecimal("1.23"), :power, real
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                      BigDecimal("1.23"), :power, real, 0
    end
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     BigDecimal("1.23"), :power, BigDecimal("2")
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigDecimal("1.23"), :power, BigDecimal("1.23"), 0
  end

  def test_plus
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     BigDecimal("1"), :+, BigDecimal("2")
    with_real(2) do |real|
      assert_send_type "(::real) -> ::BigDecimal",
                       BigDecimal("1"), :+, real
    end
    assert_send_type "(::Complex) -> ::Complex",
                     BigDecimal("1"), :+, Complex(2, 0)
  end

  def test_minus
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     BigDecimal("3"), :-, BigDecimal("1")
    with_real(1) do |real|
      assert_send_type "(::real) -> ::BigDecimal",
                       BigDecimal("3"), :-, real
    end
    assert_send_type "(::Complex) -> ::Complex",
                     BigDecimal("3"), :-, Complex(1, 0)
  end

  def test_divide
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     BigDecimal("6"), :/, BigDecimal("2")
    with_real(2) do |real|
      assert_send_type "(::real) -> ::BigDecimal",
                       BigDecimal("6"), :/, real
    end
    assert_send_type "(::Complex) -> ::Complex",
                     BigDecimal("6"), :/, Complex(2, 0)
  end

  def test_unary_plus
    assert_send_type "() -> ::BigDecimal",
                     BigDecimal("1.23"), :+@
  end

  def test_unary_minus
    assert_send_type "() -> ::BigDecimal",
                     BigDecimal("1.23"), :-@
  end

  def test_abs
    assert_send_type "() -> ::BigDecimal",
                     BigDecimal("1.23"), :abs
  end

  def test_ceil
    assert_send_type "() -> ::Integer",
                     BigDecimal("1.23"), :ceil
    assert_send_type "(::Integer n) -> ::BigDecimal",
                     BigDecimal("1.23"), :ceil, 2
  end

  def test_coerce
    assert_send_type "(::BigDecimal) -> [ ::BigDecimal, ::BigDecimal ]",
                     BigDecimal("1.23"), :coerce, BigDecimal("1.234")
  end

  def test_div
    assert_send_type "(::BigDecimal value) -> ::Integer",
                     BigDecimal("5"), :div, BigDecimal("2")
    with_real(2) do |real|
      assert_send_type "(::real value) -> ::Integer",
                       BigDecimal("5"), :div, real
    end
    assert_send_type "(::BigDecimal value, ::int digits) -> ::BigDecimal",
                     BigDecimal("1.23"), :div, BigDecimal("2"), 3
    with_real(2) do |real|
      assert_send_type "(::real value, ::int digits) -> ::BigDecimal",
                       BigDecimal("1.23"), :div, real, 3
    end
  end

  def test_divmod
    assert_send_type "(::BigDecimal) -> [ ::Integer, ::BigDecimal ]",
                     BigDecimal("5"), :divmod, BigDecimal("2")
    with_real(2) do |real|
      assert_send_type "(::real) -> [ ::Integer, ::BigDecimal ]",
                       BigDecimal("5"), :divmod, real
    end
  end

  def test_finite?
    assert_send_type "() -> bool",
                     BigDecimal("1.23"), :finite?
  end

  def test_floor
    assert_send_type "() -> ::Integer",
                     BigDecimal("1.23"), :floor
    assert_send_type "(::int n) -> ::BigDecimal",
                     BigDecimal("1.23"), :floor, 2
  end

  def test_infinite?
    assert_send_type "() -> ::Integer?",
                     BigDecimal("1.23"), :infinite?
  end

  def test_modulo
    assert_send_type "(::BigDecimal b) -> ::BigDecimal",
                     BigDecimal("5"), :modulo, BigDecimal("3")
    with_real(3) do |real|
      assert_send_type "(::real b) -> ::BigDecimal",
                       BigDecimal("5"), :modulo, real
    end
  end

  def test_nonzero?
    assert_send_type "() -> BigDecimal",
                     BigDecimal("1.23"), :nonzero?
  end

  def test_quo
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     BigDecimal("1.23"), :quo, BigDecimal("2")
    with_real(2) do |real|
      assert_send_type "(::real) -> ::BigDecimal",
                       BigDecimal("1.23"), :quo, real
    end
    assert_send_type "(::Complex) -> ::Complex",
                     BigDecimal("2"), :quo, Complex(1, 2)
  end

  def test_remainder
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     BigDecimal("5"), :remainder, BigDecimal("3")
    with_real(3) do |real|
      assert_send_type "(::real) -> ::BigDecimal",
                       BigDecimal("5"), :remainder, real
    end
  end

  def test_round
    assert_send_type "() -> ::Integer",
                     BigDecimal("3.14"), :round
    assert_send_type "(::Integer) -> ::Integer",
                     BigDecimal("3.14"), :round, 0
    assert_send_type "(::Integer) -> ::BigDecimal",
                     BigDecimal("3.14"), :round, 1
    assert_send_type "(::Integer, ::Integer) -> ::BigDecimal",
                     BigDecimal("3.14"), :round, 0, BigDecimal::ROUND_UP
    assert_send_type "(::Integer, :half_up) -> ::BigDecimal",
                     BigDecimal("3.14"), :round, 0, :half_up
    assert_send_type "(half: :up) -> ::BigDecimal",
                     BigDecimal("3.14"), :round, half: :up
    assert_send_type "(::Integer, half: :even) -> ::BigDecimal",
                     BigDecimal("3.14"), :round, 0, half: :even
  end

  def test_to_int
    assert_send_type "() -> ::Integer",
                     BigDecimal("1.23"), :to_int
  end

  def test_truncate
    assert_send_type "() -> ::Integer",
                     BigDecimal("1.23"), :truncate
    assert_send_type "(::int n) -> ::BigDecimal",
                     BigDecimal("1.23"), :truncate, 2
  end

  def test_zero?
    assert_send_type "() -> bool",
                     BigDecimal("1.23"), :zero?
  end


  def test__dump
    assert_send_type "(?untyped) -> String",
                     BigDecimal("1.23"), :_dump
  end

  def test_add
    assert_send_type "(::BigDecimal value, ::Integer digits) -> ::BigDecimal",
                     BigDecimal("1.23"), :add, BigDecimal("1.23"), 2
    with_real(1.23) do |real|
      assert_send_type "(::real value, ::Integer digits) -> ::BigDecimal",
                       BigDecimal("1.23"), :add, real, 2
    end
  end

  def test_exponent
    assert_send_type "() -> ::Integer",
                     BigDecimal("1.23"), :exponent
  end

  def test_fix
    assert_send_type "() -> ::BigDecimal",
                     BigDecimal("1.23"), :fix
  end

  def test_frac
    assert_send_type "() -> ::BigDecimal",
                     BigDecimal("1.23"), :frac
  end

  def test_mult
    assert_send_type "(::BigDecimal value, ::int digits) -> ::BigDecimal",
                     BigDecimal("1.23"), :mult, BigDecimal("1.23"), 2
    with_real(1.23) do |real|
      assert_send_type "(::real value, ::int digits) -> ::BigDecimal",
                       BigDecimal("1.23"), :mult, real, 2
    end
  end

  def test_nan?
    assert_send_type "() -> bool",
                     BigDecimal("1.23"), :nan?
  end

  def test_sign
    assert_send_type "() -> ::Integer",
                     BigDecimal("1.23"), :sign
  end

  def test_split
    assert_send_type "() -> [ ::Integer, ::String, ::Integer, ::Integer ]",
                     BigDecimal("1.23"), :split
  end

  def test_sqrt
    assert_send_type "(::int n) -> ::BigDecimal",
                     BigDecimal("1.23"), :sqrt, 2
  end

  def test_sub
    assert_send_type "(::BigDecimal value, ::int digits) -> ::BigDecimal",
                     BigDecimal("5.123"), :sub, BigDecimal("1.5"), 3
    with_real(1.5) do |real|
      assert_send_type "(::real value, ::int digits) -> ::BigDecimal",
                       BigDecimal("5.123"), :sub, real, 3
    end
  end

  def test_to_d
    assert_send_type "() -> ::BigDecimal",
                     BigDecimal("1.23"), :to_d
  end

  def test_to_f
    assert_send_type "() -> ::Float",
                     BigDecimal("1.23"), :to_f
  end

  def test_to_i
    assert_send_type "() -> ::Integer",
                     BigDecimal("1.23"), :to_i
  end

  def test_to_r
    assert_send_type "() -> ::Rational",
                     BigDecimal("1.23"), :to_r
  end
end

class IntegerToBigDecimalTest < Test::Unit::TestCase
  include TestHelper

  library "bigdecimal"
  testing "::Integer"

  def test_to_d_with_integer
    assert_send_type "() -> ::BigDecimal", 123, :to_d
  end

  def test_plus_with_integer
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     123, :+, BigDecimal("1.23")
  end

  def test_minus_with_integer
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     123, :-, BigDecimal("1.23")
  end

  def test_divide_with_integer
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     123, :/, BigDecimal("1.23")
  end

  def test_multiply_with_integer
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     123, :*, BigDecimal("1.23")
  end
end

class FloatToBigDecimalTest < Test::Unit::TestCase
  include TestHelper

  library "bigdecimal"
  testing "::Float"

  def test_to_d_with_float
    assert_send_type "() -> ::BigDecimal", 12.3, :to_d
  end

  def test_plus_with_float
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     1.23, :+, BigDecimal("1.23")
  end

  def test_minus_with_float
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     1.23, :-, BigDecimal("1.23")
  end

  def test_divide_with_float
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     1.23, :/, BigDecimal("1.23")
  end

  def test_multiply_with_float
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     1.23, :*, BigDecimal("1.23")
  end
end

class StringToBigDecimalTest < Test::Unit::TestCase
  include TestHelper

  library "bigdecimal"
  testing "::String"

  def test_to_d_with_string
    assert_send_type "() -> ::BigDecimal", "123", :to_d
  end
end

class RationalToBigDecimalTest < Test::Unit::TestCase
  include TestHelper

  library "bigdecimal"
  testing "::Rational"

  def test_to_d_with_rational
    assert_send_type "(Integer) -> ::BigDecimal", Rational(22, 7), :to_d, 3
  end

  def test_plus_with_rational
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     123r, :+, BigDecimal("1.23")
  end

  def test_minus_with_rational
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     123r, :-, BigDecimal("1.23")
  end

  def test_divide_with_rational
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     123r, :/, BigDecimal("1.23")
  end

  def test_multiply_with_rational
    assert_send_type "(::BigDecimal) -> ::BigDecimal",
                     123r, :*, BigDecimal("1.23")
  end
end

class ComplexToBigDecimalTest < Test::Unit::TestCase
  include TestHelper

  library "bigdecimal"
  testing "::Complex"

  def test_to_d_with_complex
    assert_send_type "() -> ::BigDecimal", Complex(0.1234567, 0), :to_d
  end

  def test_plus_with_complex
    assert_send_type "(::BigDecimal) -> ::Complex",
                     Complex(0.1234567, 0), :+, BigDecimal("1.23")
  end

  def test_minus_with_complex
    assert_send_type "(::BigDecimal) -> ::Complex",
                     Complex(0.1234567, 0), :-, BigDecimal("1.23")
  end

  def test_divide_with_complex
    assert_send_type "(::BigDecimal) -> ::Complex",
                     Complex(0.1234567, 0), :/, BigDecimal("1.23")
  end

  def test_multiply_with_complex
    assert_send_type "(::BigDecimal) -> ::Complex",
                     Complex(0.1234567, 0), :*, BigDecimal("1.23")
  end
end

class NilToBigDecimalTest < Test::Unit::TestCase
  include TestHelper

  library "bigdecimal"
  testing "::NilClass"

  def test_to_d_with_nil
    assert_send_type "() -> ::BigDecimal", nil, :to_d
  end
end
