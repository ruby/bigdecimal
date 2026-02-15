require "bigdecimal"
require "bigdecimal/util"
require 'test/unit'
require 'rbs/unit_test'
require_relative './test_helper'

class BigDecimalUtilTest < Test::Unit::TestCase
  include TestHelper
  library "bigdecimal"
  testing "::BigDecimal"

  def test_to_digits
    assert_send_type "() -> ::String",
                     BigDecimal("1.23"), :to_digits
  end

  def test_to_d
    assert_send_type "() -> ::BigDecimal",
                     BigDecimal("1.23"), :to_d
  end
end

class BigDecimalUtilIntegerTest < Test::Unit::TestCase
  include TestHelper

  library "bigdecimal"
  testing "::Integer"

  def test_to_d_with_integer
    assert_send_type "() -> ::BigDecimal", 123, :to_d
  end
end

class BigDecimalUtilFloatTest < Test::Unit::TestCase
  include TestHelper

  library "bigdecimal"
  testing "::Float"

  def test_to_d_with_float
    assert_send_type "() -> ::BigDecimal", 12.3, :to_d
  end
end

class BigDecimalUtilRationalTest < Test::Unit::TestCase
  include TestHelper

  library "bigdecimal"
  testing "::Rational"

  def test_to_d_with_rational
    assert_send_type "(Integer) -> ::BigDecimal", Rational(22, 7), :to_d, 3
  end
end

class BigDecimalUtilComplexTest < Test::Unit::TestCase
  include TestHelper

  library "bigdecimal"
  testing "::Complex"

  def test_to_d_with_complex
    assert_send_type "() -> ::BigDecimal", Complex(0.1234567, 0), :to_d
  end
end

class BigDecimalUtilStringTest < Test::Unit::TestCase
  include TestHelper

  library "bigdecimal"
  testing "::String"

  def test_to_d_with_string
    assert_send_type "() -> ::BigDecimal", "123", :to_d
  end
end

class BigDecimalUtilNilClassTest < Test::Unit::TestCase
  include TestHelper

  library "bigdecimal"
  testing "::NilClass"

  def test_to_d_with_nil
    assert_send_type "() -> ::BigDecimal", nil, :to_d
  end
end
