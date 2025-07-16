# frozen_string_literal: false
require_relative 'helper'
require 'bigdecimal'

class TestVpOperation < Test::Unit::TestCase
  include TestBigDecimalBase

  def setup
    super
    unless BigDecimal.instance_methods.include?(:vpdivd)
      # rake clean && BIGDECIMAL_USE_VP_TEST_METHODS=true rake compile
      omit 'Compile with BIGDECIMAL_USE_VP_TEST_METHODS=true to run this test'
    end
  end

  def test_vpmult
    assert_equal(BigDecimal('121932631112635269'), BigDecimal('123456789').vpmult(BigDecimal('987654321')))
    assert_equal(BigDecimal('12193263.1112635269'), BigDecimal('123.456789').vpmult(BigDecimal('98765.4321')))
    x = 123**456
    y = 987**123
    assert_equal(BigDecimal("#{x * y}e-300"), BigDecimal("#{x}e-100").vpmult(BigDecimal("#{y}e-200")))
  end

  def test_vpdivd
    # a[0] > b[0]
    # XXXX_YYYY_ZZZZ / 1111 #=> 000X_000Y_000Z
    x1 = BigDecimal('2' * BASE_FIG + '3' * BASE_FIG + '4' * BASE_FIG + '5' * BASE_FIG + '6' * BASE_FIG)
    y = BigDecimal('1' * BASE_FIG)
    d1 = BigDecimal("2e#{BASE_FIG * 4}")
    d2 = BigDecimal("3e#{BASE_FIG * 3}") + d1
    d3 = BigDecimal("4e#{BASE_FIG * 2}") + d2
    d4 = BigDecimal("5e#{BASE_FIG}") + d3
    d5 = BigDecimal(6) + d4
    assert_equal([d1, x1 - d1 * y], x1.vpdivd(y, 1))
    assert_equal([d2, x1 - d2 * y], x1.vpdivd(y, 2))
    assert_equal([d3, x1 - d3 * y], x1.vpdivd(y, 3))
    assert_equal([d4, x1 - d4 * y], x1.vpdivd(y, 4))
    assert_equal([d5, x1 - d5 * y], x1.vpdivd(y, 5))

    # a[0] < b[0]
    # 00XX_XXYY_YYZZ_ZZ00 / 1111 #=> 0000_0X00_0Y00_0Z00
    shift = BASE_FIG / 2
    x2 = BigDecimal('2' * BASE_FIG + '3' * BASE_FIG + '4' * BASE_FIG + '5' * BASE_FIG + '6' * BASE_FIG + '0' * shift)
    d1 = BigDecimal("2e#{4 * BASE_FIG + shift}")
    d2 = BigDecimal("3e#{3 * BASE_FIG + shift}") + d1
    d3 = BigDecimal("4e#{2 * BASE_FIG + shift}") + d2
    d4 = BigDecimal("5e#{BASE_FIG + shift}") + d3
    d5 = BigDecimal("6e#{shift}") + d4
    assert_equal([0, x2], x2.vpdivd(y, 1))
    assert_equal([d1, x2 - d1 * y], x2.vpdivd(y, 2))
    assert_equal([d2, x2 - d2 * y], x2.vpdivd(y, 3))
    assert_equal([d3, x2 - d3 * y], x2.vpdivd(y, 4))
    assert_equal([d4, x2 - d4 * y], x2.vpdivd(y, 5))
    assert_equal([d5, x2 - d5 * y], x2.vpdivd(y, 6))
  end

  def test_vpdivd_large_quotient_prec
    # 0001 / 0003 = 0000_3333_3333
    assert_equal([BigDecimal('0.' + '3' * BASE_FIG * 9), BigDecimal("1e-#{9 * BASE_FIG}")], BigDecimal(1).vpdivd(BigDecimal(3), 10))
    # 1000 / 0003 = 0333_3333_3333
    assert_equal([BigDecimal('3' * (BASE_FIG - 1) + '.' + '3' * BASE_FIG * 9), BigDecimal("1e-#{9 * BASE_FIG}")], BigDecimal(BASE / 10).vpdivd(BigDecimal(3), 10))
  end

  def test_vpdivd_with_one
    x = BigDecimal('1234.2468000001234')
    assert_equal([BigDecimal('1234'), BigDecimal('0.2468000001234')], x.vpdivd(BigDecimal(1), 1))
    assert_equal([BigDecimal('+1234.2468'), BigDecimal('+0.1234e-9')], (+x).vpdivd(BigDecimal(+1), 2))
    assert_equal([BigDecimal('-1234.2468'), BigDecimal('+0.1234e-9')], (+x).vpdivd(BigDecimal(-1), 2))
    assert_equal([BigDecimal('-1234.2468'), BigDecimal('-0.1234e-9')], (-x).vpdivd(BigDecimal(+1), 2))
    assert_equal([BigDecimal('+1234.2468'), BigDecimal('-0.1234e-9')], (-x).vpdivd(BigDecimal(-1), 2))
  end

  def test_vpdivd_precisions
    xs = [5, 10, 20, 40].map {|n| 123 ** n }
    ys = [5, 10, 20, 40].map {|n| 321 ** n }
    xs.product(ys).each do |x, y|
      [1, 2, 10, 20].each do |n|
        xn = (x.digits.size + BASE_FIG - 1) / BASE_FIG
        yn = (y.digits.size + BASE_FIG - 1) / BASE_FIG
        base = BASE ** (n - xn + yn - 1)
        div = BigDecimal((x * base / y).to_i) / base
        assert_equal([div, x - y * div], BigDecimal(x).vpdivd(y, n))
      end
    end
  end

  def test_vpdivd_carry_borrow
    y_small = BASE / 7 * BASE ** 4
    y_large = (4 * BASE_FIG).times.map {|i| i % 9 + 1 }.join.to_i
    [y_large, y_small].each do |y|
      [0, 1, 2, BASE - 2, BASE - 1].repeated_permutation(4) do |a, b, c, d|
        x = y * (3 * BASE**4 + a * BASE**3 + b * BASE**2 + c * BASE + d) / BASE
        div = BigDecimal(x * BASE / y) / BASE
        mod = BigDecimal(x) - div * y
        assert_equal([div, mod], BigDecimal(x).vpdivd(BigDecimal(y), 5))
      end
    end
  end

  def test_vpdivd_large_prec_divisor
    x = BigDecimal('2468.000000000000000000000000003')
    y1 = BigDecimal('1234.000000000000000000000000001')
    y2 = BigDecimal('1234.000000000000000000000000004')
    divy1_1 = BigDecimal(2)
    divy2_1 = BigDecimal(1)
    divy2_2 = BigDecimal('1.' + '9' * BASE_FIG)
    assert_equal([divy1_1, x - y1 * divy1_1], x.vpdivd(y1, 1))
    assert_equal([divy2_1, x - y2 * divy2_1], x.vpdivd(y2, 1))
    assert_equal([divy2_2, x - y2 * divy2_2], x.vpdivd(y2, 2))
  end

  def test_vpdivd_intermediate_zero
    if BASE_FIG == 9
      x = BigDecimal('123456789.246913578000000000123456789')
      y = BigDecimal('123456789')
      assert_equal([BigDecimal('1.000000002000000000000000001'), BigDecimal(0)], x.vpdivd(y, 4))
      assert_equal([BigDecimal('1.000000000049999999'), BigDecimal('1e-18')], BigDecimal("2.000000000099999999").vpdivd(2, 3))
    else
      x = BigDecimal('1234.246800001234')
      y = BigDecimal('1234')
      assert_equal([BigDecimal('1.000200000001'), BigDecimal(0)], x.vpdivd(y, 4))
      assert_equal([BigDecimal('1.00000499'), BigDecimal('1e-8')], BigDecimal("2.00000999").vpdivd(2, 3))
    end
  end
end
