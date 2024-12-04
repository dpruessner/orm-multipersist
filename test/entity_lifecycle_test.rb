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
    @hook_order = []
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

  set_callback :create, :before, :before_create
  set_callback :create, :after, :after_create
  set_callback :create, :around, :around_create

  set_callback :update, :before, :before_update
  set_callback :update, :after, :after_update
  set_callback :update, :around, :around_update


  # create lifecycle hooks for create
  def before_create
    @hook_order << :before_create
  end
  def after_create
    @hook_order << :after_create
  end
  def around_create
    @hook_order << :around_create
    if block_given?
      yield
      @hook_order << :around_create
    end
  end

  def before_update
    @hook_order << :before_update
    @hook_state = :before_update
  end
  def around_update
    @hook_order << :around_update
    if block_given?
      yield
      @hook_order << :around_update
    end
  end
  def after_update
    @hook_order << :after_update
  end


  attr_accessor :hook_state
  attr_accessor :hook_order
end




describe OrmMultipersist::Entity do
  describe 'lifecycle-save' do

    before do
      @klass = TestClass1
      @run_id = SecureRandom.uuid
    end

    it 'instantiates' do
      entity = @klass.new
      _(entity).wont_be_nil
    end

    it 'calls lifecycle hooks' do
      @backend = OrmMultipersist::NullBackend.new
      klass = @backend.client_for(@klass)
      obj = T.cast(klass.new, OrmMultipersist::EntityBase)
      obj.send('color=', 'red')
      obj.save!
      _(obj.send('hook_order')).must_equal [:before_create, :around_create, :around_create, :after_create]
      # update
      obj.send('color=', 'blue')
      obj.save!
      _(obj.send('hook_order')).must_equal [:before_create, :around_create, :around_create, :after_create, 
                                            :before_update, :around_update, :around_update, :after_update]
      #_(obj.send('hook_state')).must_equal :after_update
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
