# frozen_string_literal: false
require_relative "helper"
require "bigdecimal/math"

class TestBigMath < Test::Unit::TestCase
  include TestBigDecimalBase
  include BigMath
  N = 20
  # SQRT in 116 (= 100 + double_fig) digits
  SQRT2 = BigDecimal("1.4142135623730950488016887242096980785696718753769480731766797379907324784621070388503875343276415727350138462309123")
  SQRT3 = BigDecimal("1.7320508075688772935274463415058723669428052538103806280558069794519330169088000370811461867572485756756261414154067")
  PINF = BigDecimal("+Infinity")
  MINF = BigDecimal("-Infinity")
  NAN = BigDecimal("NaN")

  def test_const
    assert_in_delta(Math::PI, PI(N))
    assert_in_delta(Math::E, E(N))
  end

  def test_sqrt
    assert_in_delta(2**0.5, sqrt(BigDecimal("2"), N))
    assert_equal(10, sqrt(BigDecimal("100"), N))
    assert_equal(0.0, sqrt(BigDecimal("0"), N))
    assert_equal(0.0, sqrt(BigDecimal("-0"), N))
    assert_raise(FloatDomainError) {sqrt(BigDecimal("-1.0"), N)}
    assert_raise(FloatDomainError) {sqrt(NAN, N)}
    assert_raise(FloatDomainError) {sqrt(PINF, N)}
    assert_in_delta(SQRT2, sqrt(BigDecimal("2"), 100), BigDecimal("1e-100"))
    assert_in_delta(SQRT3, sqrt(BigDecimal("3"), 100), BigDecimal("1e-100"))
    assert_relative_precision {|n| sqrt(BigDecimal("2"), n) }
    assert_relative_precision {|n| sqrt(BigDecimal("2e-50"), n) }
    assert_relative_precision {|n| sqrt(BigDecimal("2e50"), n) }
  end

  def test_sin
    assert_in_delta(0.0, sin(BigDecimal("0.0"), N))
    assert_in_delta(Math.sqrt(2.0) / 2, sin(PI(N) / 4, N))
    assert_in_delta(1.0, sin(PI(N) / 2, N))
    assert_in_delta(0.0, sin(PI(N) * 2, N))
    assert_in_delta(0.0, sin(PI(N), N))
    assert_in_delta(-1.0, sin(PI(N) / -2, N))
    assert_in_delta(0.0, sin(PI(N) * -2, N))
    assert_in_delta(0.0, sin(-PI(N), N))
    assert_in_delta(0.0, sin(PI(N) * 21, N))
    assert_in_delta(0.0, sin(PI(N) * 30, N))
    assert_in_delta(-1.0, sin(PI(N) * BigDecimal("301.5"), N))
    assert_in_delta(BigDecimal('0.5'), sin(PI(100) / 6, 100), BigDecimal("1e-100"))
    assert_in_delta(SQRT3 / 2, sin(PI(100) / 3, 100), BigDecimal("1e-100"))
    assert_in_delta(SQRT2 / 2, sin(PI(100) / 4, 100), BigDecimal("1e-100"))
    assert_fixed_point_precision {|n| sin(BigDecimal("1"), n) }
    assert_fixed_point_precision {|n| sin(BigDecimal("1e50"), n) }
    assert_fixed_point_precision {|n| sin(BigDecimal("1e-30"), n) }
    assert_fixed_point_precision {|n| sin(BigDecimal(PI(50)), n) }
    assert_fixed_point_precision {|n| sin(BigDecimal(PI(50) * 100), n) }
    assert_operator(sin(PI(30) / 2, 30), :<=, 1)
    assert_operator(sin(-PI(30) / 2, 30), :>=, -1)
  end

  def test_cos
    assert_in_delta(1.0, cos(BigDecimal("0.0"), N))
    assert_in_delta(Math.sqrt(2.0) / 2, cos(PI(N) / 4, N))
    assert_in_delta(0.0, cos(PI(N) / 2, N))
    assert_in_delta(1.0, cos(PI(N) * 2, N))
    assert_in_delta(-1.0, cos(PI(N), N))
    assert_in_delta(0.0, cos(PI(N) / -2, N))
    assert_in_delta(1.0, cos(PI(N) * -2, N))
    assert_in_delta(-1.0, cos(-PI(N), N))
    assert_in_delta(-1.0, cos(PI(N) * 21, N))
    assert_in_delta(1.0, cos(PI(N) * 30, N))
    assert_in_delta(0.0, cos(PI(N) * BigDecimal("301.5"), N))
    assert_in_delta(BigDecimal('0.5'), cos(PI(100) / 3, 100), BigDecimal("1e-100"))
    assert_in_delta(SQRT3 / 2, cos(PI(100) / 6, 100), BigDecimal("1e-100"))
    assert_in_delta(SQRT2 / 2, cos(PI(100) / 4, 100), BigDecimal("1e-100"))
    assert_fixed_point_precision {|n| cos(BigDecimal("1"), n) }
    assert_fixed_point_precision {|n| cos(BigDecimal("1e50"), n) }
    assert_fixed_point_precision {|n| cos(BigDecimal(PI(50) / 2), n) }
    assert_fixed_point_precision {|n| cos(BigDecimal(PI(50) * 201 / 2), n) }
    assert_operator(cos(PI(30), 30), :>=, -1)
    assert_operator(cos(PI(30) * 2, 30), :<=, 1)
  end

  def test_tan
    assert_in_delta(0.0, tan(-PI(N), N))
    assert_in_delta(0.0, tan(BigDecimal(0), N))
    assert_in_delta(0.0, tan(PI(N), N))
    assert_in_delta(1.0, tan(PI(N) / 4, N))
    assert_in_delta(-1.0, tan(-PI(N) / 4, N))
    assert_in_delta(-1.0, tan(PI(N) * 3 / 4, N))
    assert_in_delta(1.0, tan(-PI(N) * 3 / 4, N))
    assert_in_delta(0.0, tan(PI(N) * 100, N))
    assert_in_delta(1.0, tan(PI(N) * 101 / 4, N))
    assert_in_delta(-1.0, tan(PI(N) * 103 / 4, N))
    assert_in_delta(BigDecimal("1").div(SQRT3, 100), tan(PI(100) / 6, 100), BigDecimal("1e-100"))
    assert_in_delta(SQRT3, tan(PI(100) / 3, 100), BigDecimal("1e-100"))
    assert_relative_precision {|n| tan(BigDecimal("0.5"), n) }
    assert_relative_precision {|n| tan(BigDecimal("1e-30"), n) }
    assert_relative_precision {|n| tan(BigDecimal("1.5"), n) }
    assert_relative_precision {|n| tan(PI(100) / 2, n) }
    assert_relative_precision {|n| tan(PI(200) * 101 / 2, n) }
    assert_relative_precision {|n| tan(PI(100), n) }
    assert_relative_precision {|n| tan(PI(200) * 100, n) }
  end

  def test_atan
    assert_equal(0.0, atan(BigDecimal("0.0"), N))
    assert_in_delta(Math::PI/4, atan(BigDecimal("1.0"), N))
    assert_in_delta(Math::PI/6, atan(sqrt(BigDecimal("3.0"), N) / 3, N))
    assert_in_delta(Math::PI/2, atan(PINF, N))
    assert_in_delta(PI(100) / 3, atan(SQRT3, 100), BigDecimal("1e-100"))
    assert_equal(BigDecimal("0.823840753418636291769355073102514088959345624027952954058347023122539489"),
                 atan(BigDecimal("1.08"), 72).round(72), '[ruby-dev:41257]')
    assert_relative_precision {|n| atan(BigDecimal("2"), n)}
    assert_relative_precision {|n| atan(BigDecimal("1e-30"), n)}
    assert_relative_precision {|n| atan(BigDecimal("1e30"), n)}
  end

  def test_log
    assert_equal(0, BigMath.log(BigDecimal("1.0"), 10))
    assert_in_epsilon(Math.log(10)*1000, BigMath.log(BigDecimal("1e1000"), 10))
    assert_in_epsilon(BigDecimal("2.3025850929940456840179914546843642076011014886287729760333279009675726096773524802359972050895982983419677840422862"),
                      BigMath.log(BigDecimal("10"), 100), BigDecimal("1e-100"))
    assert_relative_precision {|n| BigMath.log(BigDecimal("2"), n) }
    assert_relative_precision {|n| BigMath.log(BigDecimal("1e-30") + 1, n) }
    assert_relative_precision {|n| BigMath.log(BigDecimal("1e-30"), n) }
    assert_relative_precision {|n| BigMath.log(BigDecimal("1e30"), n) }
    assert_raise(Math::DomainError) {BigMath.log(BigDecimal("0"), 10)}
    assert_raise(Math::DomainError) {BigMath.log(BigDecimal("-1"), 10)}
    assert_separately(%w[-rbigdecimal], <<-SRC)
    begin
      x = BigMath.log(BigDecimal("1E19999999999999"), 10)
    rescue FloatDomainError
    else
      unless x.infinite?
        assert_in_epsilon(Math.log(10)*19999999999999, x)
      end
    end
    SRC
  end
end
