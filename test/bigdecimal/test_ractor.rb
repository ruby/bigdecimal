# frozen_string_literal: true
require_relative "helper"

class TestBigDecimalRactor < Test::Unit::TestCase
  include TestBigDecimalBase

  def setup
    super
    omit unless defined? Ractor
  end

  def test_ractor_shareable
    assert_separately([], "#{<<~"begin;"}\n#{<<~'end;'}")
    begin;
      $VERBOSE = nil
      class Ractor
        alias value take unless method_defined? :value
      end

      require "bigdecimal"
      r = Ractor.new BigDecimal(Math::PI, Float::DIG+1) do |pi|
        BigDecimal('2.0')*pi
      end
      assert_equal(2*Math::PI, r.value)
    end;
  end
end
