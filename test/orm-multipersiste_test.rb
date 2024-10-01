require 'minitest/autorun'
require 'orm-multipersist'
require_relative 'test_helpers'

class OrmMultipersistTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::OrmMultipersist::VERSION
  end

  def test_it_does_something_useful
    assert true
  end
end

