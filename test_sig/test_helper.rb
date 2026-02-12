require 'rbs/unit_test'

module TestHelper
  include RBS::UnitTest::TypeAssertions
  include RBS::UnitTest::Convertibles

  def self.included(base)
    base.extend RBS::UnitTest::TypeAssertions::ClassMethods
  end

  def with_real(n)
    yield n.to_i
    yield n.to_f
    yield n.to_r
  end
end
