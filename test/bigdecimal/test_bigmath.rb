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
  SQRT5 = BigDecimal("2.2360679774997896964091736687312762354406183596115257242708972454105209256378048994144144083787822749695081761507738")
  PINF = BigDecimal("+Infinity")
  MINF = BigDecimal("-Infinity")
  NAN = BigDecimal("NaN")

  def test_pi
    assert_equal(
      BigDecimal("3.141592653589793238462643383279502884197169399375105820974944592307816406286208998628034825342117068"),
      PI(100)
    )
    assert_converge_in_precision {|n| PI(n) }
  end

  def test_e
    assert_equal(
      BigDecimal("2.718281828459045235360287471352662497757247093699959574966967627724076630353547594571382178525166427"),
      E(100)
    )
    assert_converge_in_precision {|n| E(n) }
  end

  def assert_consistent_precision_acceptance(accept_zero: false)
    value = yield 5
    assert_equal(value, yield(5.9))

    obj_with_to_int = Object.new
    obj_with_to_int.define_singleton_method(:to_int) { 5 }
    assert_equal(value, yield(obj_with_to_int))

    wrong_to_int = Object.new
    wrong_to_int.define_singleton_method(:to_int) { 5.5 }
    assert_raise(TypeError) { yield wrong_to_int }

    assert_raise(TypeError) { yield nil }
    assert_raise(TypeError) { yield '5' }
    assert_raise(ArgumentError) { yield(-1) }
    if accept_zero
      assert_nothing_raised { yield 0 }
    else
      assert_raise(ArgumentError) { yield 0 }
    end
  end

  def test_consistent_precision_acceptance
    x = BigDecimal('1.23456789')
    # Exclude div because div(x, nil) is a special case
    assert_consistent_precision_acceptance(accept_zero: true) {|prec| x.add(x, prec) }
    assert_consistent_precision_acceptance(accept_zero: true) {|prec| x.sub(x, prec) }
    assert_consistent_precision_acceptance(accept_zero: true) {|prec| x.mult(x, prec) }
    assert_consistent_precision_acceptance(accept_zero: true) {|prec| x.power(x, prec) }
    assert_consistent_precision_acceptance(accept_zero: true) {|prec| x.sqrt(prec) }
    assert_consistent_precision_acceptance {|prec| BigMath.sqrt(x, prec) }
    assert_consistent_precision_acceptance {|prec| BigMath.exp(x, prec) }
    assert_consistent_precision_acceptance {|prec| BigMath.log(x, prec) }
    assert_consistent_precision_acceptance {|prec| BigMath.sin(x, prec) }
    assert_consistent_precision_acceptance {|prec| BigMath.cos(x, prec) }
    assert_consistent_precision_acceptance {|prec| BigMath.tan(x, prec) }
    assert_consistent_precision_acceptance {|prec| BigMath.atan(x, prec) }
    assert_consistent_precision_acceptance {|prec| BigMath.E(prec) }
    assert_consistent_precision_acceptance {|prec| BigMath.PI(prec) }
  end

  def test_sqrt
    assert_in_delta(2**0.5, sqrt(BigDecimal("2"), N))
    assert_equal(10, sqrt(BigDecimal("100"), N))
    assert_equal(0.0, sqrt(BigDecimal("0"), N))
    assert_equal(0.0, sqrt(BigDecimal("-0"), N))
    assert_raise(FloatDomainError) {sqrt(BigDecimal("-1.0"), N)}
    assert_raise(FloatDomainError) {sqrt(NAN, N)}
    assert_raise(FloatDomainError) {sqrt(PINF, N)}
    assert_in_exact_precision(SQRT2, sqrt(BigDecimal("2"), 100), 100)
    assert_in_exact_precision(SQRT3, sqrt(BigDecimal("3"), 100), 100)
    assert_converge_in_precision {|n| sqrt(BigDecimal("2"), n) }
    assert_converge_in_precision {|n| sqrt(BigDecimal("2e-50"), n) }
    assert_converge_in_precision {|n| sqrt(BigDecimal("2e50"), n) }
  end

  def test_cbrt
    assert_equal(1234, cbrt(BigDecimal(1234**3), N))
    assert_equal(-12345, cbrt(BigDecimal(-12345**3), N))
    assert_equal(12345678987654321, cbrt(BigDecimal(12345678987654321) ** 3, N))
    assert_equal(0, cbrt(BigDecimal("0"), N))
    assert_equal(0, cbrt(BigDecimal("-0"), N))
    assert_positive_infinite_calculation { cbrt(PINF, N) }
    assert_negative_infinite_calculation { cbrt(MINF, N) }

    assert_in_exact_precision(SQRT2, cbrt(SQRT2 ** 3, 100), 100)
    assert_in_exact_precision(SQRT3, cbrt(SQRT3 ** 3, 100), 100)
    assert_equal(BigDecimal("3e50"), cbrt(BigDecimal("27e150"), N))
    assert_equal(BigDecimal("-4e50"), cbrt(BigDecimal("-64e150"), N))
    assert_in_epsilon(Math.cbrt(28e150), cbrt(BigDecimal("28e150"), N))
    assert_in_epsilon(Math.cbrt(27e151), cbrt(BigDecimal("27e151"), N))
    assert_converge_in_precision {|n| cbrt(BigDecimal("2"), n) }
    assert_converge_in_precision {|n| cbrt(BigDecimal("2e-50"), n) }
    assert_converge_in_precision {|n| cbrt(SQRT2, n) }
    assert_converge_in_precision {|n| cbrt(BigDecimal("2e50"), n) }
  end

  def test_hypot
    assert_in_exact_precision(SQRT2, hypot(BigDecimal("1"), BigDecimal("1"), 100), 100)
    assert_in_exact_precision(SQRT5, hypot(SQRT2, SQRT3, 100), 100)
    assert_equal(0, hypot(BigDecimal(0), BigDecimal(0), N))
    assert_positive_infinite_calculation { hypot(PINF, SQRT3, N) }
    assert_positive_infinite_calculation { hypot(SQRT3, MINF, N) }
    assert_converge_in_precision {|n| hypot(BigDecimal("1e-30"), BigDecimal("2e-30"), n) }
    assert_converge_in_precision {|n| hypot(BigDecimal("1.23"), BigDecimal("4.56"), n) }
    assert_converge_in_precision {|n| hypot(SQRT2 - 1, SQRT3 - 1, n) }
    assert_converge_in_precision {|n| hypot(BigDecimal("2e30"), BigDecimal("1e30"), n) }
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
    assert_in_exact_precision(BigDecimal('0.5'), sin(PI(100) / 6, 100), 100)
    assert_in_exact_precision(SQRT3 / 2, sin(PI(100) / 3, 100), 100)
    assert_in_exact_precision(SQRT2 / 2, sin(PI(100) / 4, 100), 100)
    assert_converge_in_precision {|n| sin(BigDecimal("1"), n) }
    assert_converge_in_precision {|n| sin(BigDecimal("1e50"), n) }
    assert_converge_in_precision {|n| sin(BigDecimal("1e-30"), n) }
    assert_converge_in_precision {|n| sin(BigDecimal(PI(50)), n) }
    assert_converge_in_precision {|n| sin(BigDecimal(PI(50) * 100), n) }
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
    assert_in_exact_precision(BigDecimal('0.5'), cos(PI(100) / 3, 100), 100)
    assert_in_exact_precision(SQRT3 / 2, cos(PI(100) / 6, 100), 100)
    assert_in_exact_precision(SQRT2 / 2, cos(PI(100) / 4, 100), 100)
    assert_converge_in_precision {|n| cos(BigDecimal("1"), n) }
    assert_converge_in_precision {|n| cos(BigDecimal("1e50"), n) }
    assert_converge_in_precision {|n| cos(BigDecimal(PI(50) / 2), n) }
    assert_converge_in_precision {|n| cos(BigDecimal(PI(50) * 201 / 2), n) }
    assert_operator(cos(PI(30), 30), :>=, -1)
    assert_operator(cos(PI(30) * 2, 30), :<=, 1)
  end

  def test_tan
    assert_in_delta(0.0, tan(BigDecimal("0.0"), N))
    assert_in_delta(0.0, tan(PI(N), N))
    assert_in_delta(1.0, tan(PI(N) / 4, N))
    assert_in_delta(sqrt(BigDecimal(3), N), tan(PI(N) / 3, N))
    assert_in_delta(sqrt(BigDecimal(3), 10 * N), tan(PI(10 * N) / 3, 10 * N))
    assert_in_delta(0.0, tan(-PI(N), N))
    assert_in_delta(-1.0, tan(-PI(N) / 4, N))
    assert_in_delta(-sqrt(BigDecimal(3), N), tan(-PI(N) / 3, N))
    assert_in_exact_precision(SQRT3, tan(PI(100) / 3, 100), 100)
    assert_converge_in_precision {|n| tan(1, n) }
    assert_converge_in_precision {|n| tan(BigMath::PI(50) / 2, n) }
    assert_converge_in_precision {|n| tan(BigMath::PI(50), n) }
  end

  def test_asin
    ["-1", "-0.9", "-0.1", "0", "0.1", "0.9", "1"].each do |x|
      assert_in_delta(Math.asin(x.to_f), asin(BigDecimal(x), N))
    end
    assert_raise(Math::DomainError) { BigMath.asin(BigDecimal("1.1"), N) }
    assert_raise(Math::DomainError) { BigMath.asin(BigDecimal("-1.1"), N) }
    assert_in_exact_precision(PI(100) / 6, asin(BigDecimal("0.5"), 100), 100)
    assert_converge_in_precision {|n| asin(BigDecimal("-0.4"), n) }
    assert_converge_in_precision {|n| asin(BigDecimal("0.3"), n) }
    assert_converge_in_precision {|n| asin(SQRT2 / 2, n) }
    assert_converge_in_precision {|n| asin(BigDecimal("0.9"), n) }
    assert_converge_in_precision {|n| asin(BigDecimal("0.#{"9" * 50}"), n) }
    assert_converge_in_precision {|n| asin(BigDecimal("0.#{"9" * 100}"), n) }
    assert_converge_in_precision {|n| asin(BigDecimal("0.#{"9" * 195}"), n) }
    assert_converge_in_precision {|n| asin(BigDecimal("1e-30"), n) }
  end

  def test_acos
    ["-1", "-0.9", "-0.1", "0", "0.1", "0.9", "1"].each do |x|
      assert_in_delta(Math.acos(x.to_f), acos(BigDecimal(x), N))
    end
    assert_raise(Math::DomainError) { BigMath.acos(BigDecimal("1.1"), N) }
    assert_raise(Math::DomainError) { BigMath.acos(BigDecimal("-1.1"), N) }
    assert_equal(0, acos(BigDecimal("1.0"), N))
    assert_in_exact_precision(PI(100) / 3, acos(BigDecimal("0.5"), 100), 100)
    assert_converge_in_precision {|n| acos(BigDecimal("-0.4"), n) }
    assert_converge_in_precision {|n| acos(BigDecimal("0.3"), n) }
    assert_converge_in_precision {|n| acos(SQRT2 / 2, n) }
    assert_converge_in_precision {|n| acos(BigDecimal("0.9"), n) }
    assert_converge_in_precision {|n| acos(BigDecimal("0.#{"9" * 50}"), n) }
    assert_converge_in_precision {|n| acos(BigDecimal("0.#{"9" * 100}"), n) }
    assert_converge_in_precision {|n| acos(BigDecimal("0.#{"9" * 195}"), n) }
    assert_converge_in_precision {|n| acos(BigDecimal("1e-30"), n) }
  end

  def test_atan
    assert_equal(0.0, atan(BigDecimal("0.0"), N))
    assert_in_delta(Math::PI/4, atan(BigDecimal("1.0"), N))
    assert_in_delta(Math::PI/6, atan(sqrt(BigDecimal("3.0"), N) / 3, N))
    assert_in_delta(Math::PI/2, atan(PINF, N))
    assert_in_exact_precision(PI(100) / 3, atan(SQRT3, 100), 100)
    assert_equal(BigDecimal("0.823840753418636291769355073102514088959345624027952954058347023122539489"),
                 atan(BigDecimal("1.08"), 72).round(72), '[ruby-dev:41257]')
    assert_converge_in_precision {|n| atan(BigDecimal("2"), n)}
    assert_converge_in_precision {|n| atan(BigDecimal("1e-30"), n)}
    assert_converge_in_precision {|n| atan(BigDecimal("1e30"), n)}
  end

  def test_atan2
    zero = BigDecimal(0)
    one = BigDecimal(1)
    assert_equal(0, atan2(zero, zero, N))
    assert_equal(0, atan2(zero, one, N))
    [MINF, -one, -zero, zero, one, PINF].repeated_permutation(2) do |y, x|
      assert_in_delta(Math::atan2(y.to_f, x.to_f), atan2(y, x, N))
    end
    assert_in_exact_precision(PI(100), atan2(zero, -one, 100), 100)
    assert_in_exact_precision(PI(100) / 2, atan2(one, zero, 100), 100)
    assert_in_exact_precision(-PI(100) / 2, atan2(-one, zero, 100), 100)
    assert_in_exact_precision(PI(100) / 3, atan2(BigDecimal(3), SQRT3, 100), 100)
    assert_in_exact_precision(PI(100) / 6, atan2(SQRT3, BigDecimal(3), 100), 100)
    assert_converge_in_precision {|n| atan2(SQRT2, SQRT3, n) }
    ['-1e20', '-2', '-1e-30', '1e-30', '2', '1e20'].repeated_permutation(2) do |y, x|
      assert_in_delta(Math.atan2(y.to_f, x.to_f), atan2(BigDecimal(y), BigDecimal(x), N))
      assert_converge_in_precision {|n| atan2(BigDecimal(y), BigDecimal(x), n) }
    end
  end

  def test_hyperbolic
    [-1, 0, 0.5, 1, 10].each do |x|
      assert_in_delta(Math.sinh(x), sinh(BigDecimal(x.to_s), N))
      assert_in_delta(Math.cosh(x), cosh(BigDecimal(x.to_s), N))
      assert_in_delta(Math.tanh(x), tanh(BigDecimal(x.to_s), N))
    end
    assert_negative_infinite_calculation { sinh(MINF, N) }
    assert_positive_infinite_calculation { sinh(PINF, N) }
    assert_positive_infinite_calculation { cosh(MINF, N) }
    assert_positive_infinite_calculation { cosh(PINF, N) }
    assert_equal(-1, tanh(MINF, N))
    assert_equal(+1, tanh(PINF, N))

    x = BigDecimal("0.3")
    assert_in_exact_precision(sinh(x, 120) / cosh(x, 120), tanh(x, 100), 100)
    assert_in_exact_precision(tanh(x, 120) * cosh(x, 120), sinh(x, 100), 100)
    assert_in_exact_precision(sinh(x, 120) / tanh(x, 120), cosh(x, 100), 100)

    e = E(120)
    assert_in_exact_precision((e - 1 / e) / 2, sinh(BigDecimal(1), 100), 100)
    assert_in_exact_precision((e + 1 / e) / 2, cosh(BigDecimal(1), 100), 100)
    assert_in_exact_precision((e - 1 / e) / (e + 1 / e), tanh(BigDecimal(1), 100), 100)

    ["1e-30", "0.2", SQRT2, "10", "100"].each do |x|
      assert_converge_in_precision {|n| sinh(BigDecimal(x), n)}
      assert_converge_in_precision {|n| cosh(BigDecimal(x), n)}
      assert_converge_in_precision {|n| tanh(BigDecimal(x), n)}
    end
  end

  def test_asinh
    [-3, 0.5, 10].each do |x|
      assert_in_delta(Math.asinh(x), asinh(BigDecimal(x.to_s), N))
    end
    assert_equal(0, asinh(BigDecimal(0), N))
    assert_positive_infinite_calculation { asinh(PINF, N) }
    assert_negative_infinite_calculation { asinh(MINF, N) }

    x = SQRT2 / 2
    assert_in_exact_precision(x, asinh(sinh(x, 120), 100), 100)

    ["1e-30", "0.2", "10", "100"].each do |x|
      assert_converge_in_precision {|n| asinh(BigDecimal(x), n)}
    end
  end

  def test_acosh
    [1.5, 2, 10].each do |x|
      assert_in_delta(Math.acosh(x), acosh(BigDecimal(x.to_s), N))
    end
    assert_equal(0, acosh(BigDecimal(1), N))
    assert_positive_infinite_calculation { acosh(PINF, N) }

    x = SQRT2
    assert_in_exact_precision(x, acosh(cosh(x, 120), 100), 100)

    ["1." + "0" * 30 + "1", "1.5", "2", "100"].each do |x|
      assert_converge_in_precision {|n| acosh(BigDecimal(x), n)}
    end
  end

  def test_atanh
    [-0.5, 0.1, 0.9].each do |x|
      assert_in_delta(Math.atanh(x), atanh(BigDecimal(x.to_s), N))
    end
    assert_equal(0, atanh(BigDecimal(0), N))
    assert_positive_infinite_calculation { atanh(BigDecimal(1), N) }
    assert_negative_infinite_calculation { atanh(BigDecimal(-1), N) }

    x = SQRT2 / 2
    assert_in_exact_precision(x, atanh(tanh(x, 120), 100), 100)

    ["1e-30", "0.5", "0.9" + "9" * 30].each do |x|
      assert_converge_in_precision {|n| atanh(BigDecimal(x), n)}
    end
  end

  def test_exp
    [-100, -2, 0.5, 10, 100].each do |x|
      assert_in_epsilon(Math.exp(x), BigMath.exp(BigDecimal(x, 0), N))
    end
    assert_equal(1, BigMath.exp(BigDecimal("0"), N))
    assert_in_exact_precision(
      BigDecimal("4.48168907033806482260205546011927581900574986836966705677265008278593667446671377298105383138245339138861635065183019577"),
      BigMath.exp(BigDecimal("1.5"), 100),
      100
    )
    assert_converge_in_precision {|n| BigMath.exp(BigDecimal("1"), n) }
    assert_converge_in_precision {|n| BigMath.exp(BigDecimal("-2"), n) }
    assert_converge_in_precision {|n| BigMath.exp(BigDecimal("-34"), n) }
    assert_converge_in_precision {|n| BigMath.exp(BigDecimal("567"), n) }
    assert_converge_in_precision {|n| BigMath.exp(SQRT2, n) }
  end

  def test_log
    assert_equal(0, BigMath.log(BigDecimal("1.0"), 10))
    assert_in_epsilon(Math.log(10)*1000, BigMath.log(BigDecimal("1e1000"), 10))
    assert_in_exact_precision(
      BigDecimal("2.3025850929940456840179914546843642076011014886287729760333279009675726096773524802359972050895982983419677840422862"),
      BigMath.log(BigDecimal("10"), 100),
      100
    )
    assert_converge_in_precision {|n| BigMath.log(BigDecimal("2"), n) }
    assert_converge_in_precision {|n| BigMath.log(BigDecimal("1e-30") + 1, n) }
    assert_converge_in_precision {|n| BigMath.log(BigDecimal("1e-30"), n) }
    assert_converge_in_precision {|n| BigMath.log(BigDecimal("1e30"), n) }
    assert_converge_in_precision {|n| BigMath.log(SQRT2, n) }
    assert_raise(Math::DomainError) {BigMath.log(BigDecimal("-0.1"), 10)}
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

  def test_log2
    assert_raise(Math::DomainError) { log2(BigDecimal("-0.01"), N) }
    assert_raise(Math::DomainError) { log2(MINF, N) }
    assert_positive_infinite_calculation { log2(PINF, N) }
    assert_in_exact_precision(
      BigDecimal("1.5849625007211561814537389439478165087598144076924810604557526545410982277943585625222804749180882420909806624750592"),
      log2(BigDecimal("3"), 100),
      100
    )
    assert_converge_in_precision {|n| log2(SQRT2, n) }
    assert_converge_in_precision {|n| log2(BigDecimal("3e20"), n) }
    assert_converge_in_precision {|n| log2(BigDecimal("1e-20") + 1, n) }
    [BigDecimal::ROUND_UP, BigDecimal::ROUND_DOWN].each do |round_mode|
      BigDecimal.mode(BigDecimal::ROUND_MODE, round_mode)
      [0, 1, 2, 11, 123].each do |n|
        assert_equal(n, log2(BigDecimal(2**n), N))
      end
    end
  end

  def test_log10
    assert_raise(Math::DomainError) { log10(BigDecimal("-0.01"), N) }
    assert_raise(Math::DomainError) { log10(MINF, N) }
    assert_positive_infinite_calculation { log10(PINF, N) }
    assert_in_exact_precision(
      BigDecimal("0.4771212547196624372950279032551153092001288641906958648298656403052291527836611230429683556476163015104646927682520"),
      log10(BigDecimal("3"), 100),
      100
    )
    assert_converge_in_precision {|n| log10(SQRT2, n) }
    assert_converge_in_precision {|n| log10(BigDecimal("3e20"), n) }
    assert_converge_in_precision {|n| log10(BigDecimal("1e-20") + 1, n) }
    [BigDecimal::ROUND_UP, BigDecimal::ROUND_DOWN].each do |round_mode|
      BigDecimal.mode(BigDecimal::ROUND_MODE, round_mode)
      [0, 1, 2, 11, 123].each do |n|
        assert_equal(n, log10(BigDecimal(10**n), N))
      end
    end
  end
end
