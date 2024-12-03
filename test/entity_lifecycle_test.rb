# typed: true

require 'minitest/autorun'
require 'minitest/expectations'
require 'orm-multipersist'
require 'orm-multipersist/null-backend'
require 'minitest/spec'

require_relative 'test_helpers'

module IEntityDefinition
  def self.attribute(*args, **kwargs); end
end

def _(*args, **kwargs)
end

class TestClass1
  extend T::Sig
  include ActiveModel::Model
  include OrmMultipersist::Entity
  k = T.cast(self, T.class_of(ActiveModel::Attributes))


  k.attribute :id, :integer, primary_key: true
  k.attribute :color, :string

  def initialize(params={})
    super
    @hook_state = nil
  end

  def self.anonymous_class?
    true
  end
  def self.name
    "AnonymousTestClass"
  end
  def do_assert_hook_state!(expected)
    if @hook_state != expected
      raise "Hook state assertion failed: expected [#{expected}] but got [#{@hook_state}]"
    end
  end

  # Create lifecycle hooks for create
  def beore_create_hook
    do_assert_hook_state! nil
    @hook_state = :before_create
  end
  def after_create_hook
    do_assert_hook_state! :around_create
    @hook_state = :after_create
  end
  def around_create_hook
    do_assert_hook_state! :before_create
    @hook_state = :around_create
  end

  attr_accessor :hook_state
end




describe OrmMultipersist::Entity do
  describe 'lifecycle-create' do
    before do
      @klass = TestClass1
    end

      @run_id = SecureRandom.uuid


    it 'instantiates' do
      entity = @klass.new
      _(entity).wont_be_nil
    end

    it 'writes to a null backend' do
      @backend = OrmMultipersist::NullBackend.new
      klass = @backend.client_for(@klass)
      binding.pry
      entity = T.cast(klass.new, OrmMultipersist::IEntity)
      entity.save
    end

##     it 'has a settable id' do
##       entity = @klass.new
##       _(entity).must_respond_to(:id)
##       _(entity).must_respond_to(:id=)
## 
##       entity.id = 100
##       _(entity.id).must_equal 100
##     end
## 
##     it 'tracks changes of an attribute' do
##       entity = @klass.new
##       entity.id = 100
##       _(entity.changes).must_equal({"id" => [nil, 100]})
##       entity.id = 200
##       _(entity.changes).must_equal({"id" => [nil, 200]})
##     end
## 
##     it 'tracks persistence' do
##       entity = @klass.new
##       entity.id = 100
##       _(entity.persisted?).must_equal false
##       entity.set_persisted
##       _(entity.persisted?).must_equal true
##     end
## 
## 
##     it 'can have the primary_key set' do
##       entity = @klass.new
##       entity.assign_primary_key_attribute(30)
##       _(entity.id).must_equal 30
##     end
## 
##     it 'can be created by a hash' do
##       entity = @klass.new(id: 10, color: 'red')
##       _(entity.id).must_equal 10
##       _(entity.color).must_equal 'red'
##       _(entity.changes).must_equal({"id" => [nil, 10], "color" => [nil, "red"]})
##     end
## 
##     it 'has classmethod identifying primary key' do
##       _(@klass.primary_key?).must_equal true
##       _(@klass.primary_key).must_equal :id
##     end

  end
end
