require "bigdecimal"
require "bigdecimal/math"
require 'test/unit'
require 'rbs/unit_test'

class BigMathSingletonTest < Test::Unit::TestCase
  include TestHelper
  library "bigdecimal"
  testing "singleton(::BigMath)"

  def test_E
    assert_send_type "(::Integer prec) -> ::BigDecimal",
                     BigMath, :E, 10
  end

  def test_PI
    assert_send_type "(::Integer prec) -> ::BigDecimal",
                     BigMath, :PI, 10
  end

  def test_acos
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :acos, BigDecimal('0.5'), 32
    with_real(0.5) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :acos, real, 32
    end
  end

  def test_acosh
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :acosh, BigDecimal('2'), 32
    with_real(2) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :acosh, real, 32
    end
  end

  def test_asin
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :asin, BigDecimal('0.5'), 32
    with_real(0.5) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :asin, real, 32
    end
  end

  def test_asinh
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :asinh, BigDecimal('1'), 32
    with_real(1) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :asinh, real, 32
    end
  end

  def test_atan
    assert_send_type "(::BigDecimal x, ::Integer prec) -> ::BigDecimal",
                     BigMath, :atan, BigDecimal('-1'), 32
    with_real(-1) do |real|
      assert_send_type "(::real x, ::Integer prec) -> ::BigDecimal",
                       BigMath, :atan, real, 32
    end
  end

  def test_atan2
    assert_send_type "(::BigDecimal, ::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :atan2, BigDecimal('-1'), BigDecimal('1'), 32
    with_real(-1) do |real_y|
      with_real(1) do |real_x|
        assert_send_type "(::real, ::real, ::Integer) -> ::BigDecimal",
                         BigMath, :atan2, real_y, real_x, 32
      end
    end
  end

  def test_atanh
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :atanh, BigDecimal('0.5'), 32
    with_real(0.5) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :atanh, real, 32
    end
  end

  def test_cbrt
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :cbrt, BigDecimal('2'), 32
    with_real(2) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :cbrt, real, 32
    end
  end

  def test_cos
    assert_send_type "(::BigDecimal x, ::Integer prec) -> ::BigDecimal",
                     BigMath, :cos, BigMath.PI(16), 32
    with_real(1) do |real|
      assert_send_type "(::real x, ::Integer prec) -> ::BigDecimal",
                       BigMath, :cos, real, 10
    end
  end

  def test_cosh
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :cosh, BigDecimal('1'), 32
    with_real(1) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :cosh, real, 32
    end
  end

  def test_erf
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :erf, BigDecimal('1'), 32
    with_real(1) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :erf, real, 32
    end
  end

  def test_erfc
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :erfc, BigDecimal('10'), 32
    with_real(10) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :erfc, real, 32
    end
  end

  def test_exp
    assert_send_type "(::BigDecimal, ::Integer prec) -> ::BigDecimal",
                     BigMath, :exp, BigDecimal('1'), 10
    with_real(1) do |real|
      assert_send_type "(::real, ::Integer prec) -> ::BigDecimal",
                       BigMath, :exp, real, 10
    end
  end

  def test_expm1
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :expm1, BigDecimal('0.1'), 32
    with_real(0.1) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :expm1, real, 32
    end
  end

  def test_frexp
    assert_send_type "(::BigDecimal) -> [::BigDecimal, ::Integer]",
                     BigMath, :frexp, BigDecimal(123.456)
    with_real(123.456) do |real|
      assert_send_type "(::real) -> [::BigDecimal, ::Integer]",
                       BigMath, :frexp, real
    end
  end

  def test_gamma
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :gamma, BigDecimal('0.5'), 32
    with_real(2) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :gamma, real, 32
    end
  end

  def test_hypot
    assert_send_type "(::BigDecimal, ::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :hypot, BigDecimal('1'), BigDecimal('2'), 32
    with_real(1) do |real_x|
      with_real(2) do |real_y|
        assert_send_type "(::real, ::real, ::Integer) -> ::BigDecimal",
                         BigMath, :hypot, real_x, real_y, 32
      end
    end
  end

  def test_ldexp
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :ldexp, BigDecimal("0.123456e0"), 3
    with_real(0.123456) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :ldexp, real, 3
    end
  end

  def test_lgamma
    assert_send_type "(::BigDecimal, ::Integer) -> [::BigDecimal, ::Integer]",
                     BigMath, :lgamma, BigDecimal('0.5'), 32
    with_real(2) do |real|
      assert_send_type "(::real, ::Integer) -> [::BigDecimal, ::Integer]",
                       BigMath, :lgamma, real, 32
    end
  end

  def test_log
    assert_send_type "(::BigDecimal, ::Integer prec) -> ::BigDecimal",
                     BigMath, :log, BigDecimal('1'), 10
    with_real(1) do |real|
      assert_send_type "(::real, ::Integer prec) -> ::BigDecimal",
                      BigMath, :log, real, 10
    end
  end

  def test_log10
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :log10, BigDecimal('3'), 32
    with_real(3) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                      BigMath, :log10, real, 32
    end
  end

  def test_log1p
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :log1p, BigDecimal('0.1'), 32
    with_real(0.1) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                      BigMath, :log1p, real, 32
    end
  end

  def test_log2
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :log2, BigDecimal('3'), 32
    with_real(3) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                      BigMath, :log2, real, 32
    end
  end

  def test_sin
    assert_send_type "(::BigDecimal x, ::Integer prec) -> ::BigDecimal",
                     BigMath, :sin, BigMath.PI(5) / 4, 32
    with_real(1) do |real|
      assert_send_type "(::real x, ::Integer prec) -> ::BigDecimal",
                       BigMath, :sin, real, 10
    end
  end

  def test_sinh
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :sinh, BigDecimal('1'), 32
    with_real(1) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :sinh, real, 32
    end
  end

  def test_sqrt
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :sqrt, BigDecimal('2'), 32
    with_real(2) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :sqrt, real, 32
    end
  end

  def test_tan
    assert_send_type "(::BigDecimal x, ::Integer prec) -> ::BigDecimal",
                     BigMath, :tan, BigDecimal("0.0"), 4
    assert_send_type "(::BigDecimal x, ::Integer prec) -> ::BigDecimal",
                     BigMath, :tan, BigMath.PI(24) / 4, 32
    with_real(1) do |real|
      assert_send_type "(::real x, ::Integer prec) -> ::BigDecimal",
                       BigMath, :tan, real, 10
    end
  end

  def test_tanh
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     BigMath, :tanh, BigDecimal('1'), 32
    with_real(1) do |real|
      assert_send_type "(::real, ::Integer) -> ::BigDecimal",
                       BigMath, :tanh, real, 32
    end
  end
end

class BigMathTest < Test::Unit::TestCase
  include TestHelper
  library "bigdecimal"
  testing "::BigMath"

  class TestClass
    include BigMath
  end

  def test_E
    assert_send_type "(::Integer prec) -> ::BigDecimal",
                     TestClass.new, :E, 10
  end

  def test_PI
    assert_send_type "(::Integer prec) -> ::BigDecimal",
                     TestClass.new, :PI, 10
  end

  def test_acos
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :acos, BigDecimal('0.5'), 32
  end

  def test_acosh
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :acosh, BigDecimal('2'), 32
  end

  def test_asin
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :asin, BigDecimal('0.5'), 32
  end

  def test_asinh
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :asinh, BigDecimal('1'), 32
  end

  def test_atan
    assert_send_type "(::BigDecimal x, ::Integer prec) -> ::BigDecimal",
                     TestClass.new, :atan, BigDecimal('1.23'), 10
  end

  def test_atan2
    assert_send_type "(::BigDecimal, ::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :atan2, BigDecimal('-1'), BigDecimal('1'), 32
  end

  def test_atanh
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :atanh, BigDecimal('0.5'), 32
  end

  def test_cbrt
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :cbrt, BigDecimal('2'), 32
  end

  def test_cos
    assert_send_type "(::BigDecimal x, ::Integer prec) -> ::BigDecimal",
                     TestClass.new, :cos, BigDecimal('1.23'), 10
  end

  def test_cosh
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :cosh, BigDecimal('1'), 32
  end

  def test_erf
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :erf, BigDecimal('1'), 32
  end

  def test_erfc
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :erfc, BigDecimal('10'), 32
  end

  def test_exp
    assert_send_type "(::BigDecimal, ::Integer prec) -> ::BigDecimal",
                     TestClass.new, :exp, BigDecimal('1.23'), 10
  end

  def test_expm1
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :expm1, BigDecimal('0.1'), 32
  end

  def test_frexp
    assert_send_type "(::BigDecimal) -> [::BigDecimal, ::Integer]",
                     TestClass.new, :frexp, BigDecimal(123.456)
  end

  def test_gamma
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :gamma, BigDecimal('0.5'), 32
  end

  def test_hypot
    assert_send_type "(::BigDecimal, ::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :hypot, BigDecimal('1'), BigDecimal('2'), 32
  end

  def test_ldexp
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :ldexp, BigDecimal("0.123456e0"), 3
  end

  def test_lgamma
    assert_send_type "(::BigDecimal, ::Integer) -> [::BigDecimal, ::Integer]",
                     TestClass.new, :lgamma, BigDecimal('0.5'), 32
  end

  def test_log
    assert_send_type "(::BigDecimal, ::Integer prec) -> ::BigDecimal",
                     TestClass.new, :log, BigDecimal('1.23'), 10
  end

  def test_log10
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :log10, BigDecimal('3'), 32
  end

  def test_log1p
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :log1p, BigDecimal('0.1'), 32
  end

  def test_log2
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :log2, BigDecimal('3'), 32
  end

  def test_sin
    assert_send_type "(::BigDecimal x, ::Integer prec) -> ::BigDecimal",
                     TestClass.new, :sin, BigDecimal('1.23'), 10
  end

  def test_sinh
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :sinh, BigDecimal('1'), 32
  end

  def test_sqrt
    assert_send_type "(::BigDecimal x, ::Integer prec) -> ::BigDecimal",
                     TestClass.new, :sqrt, BigDecimal('1.23'), 10
  end

  def test_tan
    assert_send_type "(::BigDecimal x, ::Integer prec) -> ::BigDecimal",
                     TestClass.new, :tan, BigDecimal("0.0"), 4
  end

  def test_tanh
    assert_send_type "(::BigDecimal, ::Integer) -> ::BigDecimal",
                     TestClass.new, :tanh, BigDecimal('1'), 32
  end
end
