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

class TimestampTestClass
  extend T::Sig
  include ActiveModel::Model
  include OrmMultipersist::Entity
  include OrmMultipersist::EntityTimestamps

  T.cast(self, T.class_of(ActiveModel::Attributes)).tap do |k|
    k.attribute :id, :integer, primary_key: true
    k.attribute :color, :string
  end
end

##  # Patch our 'Time.now' method to return a thread-local time if defined
##  Time.define_singleton_method(:now) do
##    ttime = Thread.current[:local_time]
##    return ttime unless ttime.nil?
##    Time.new
##  end
##  
##  Time.define_singleton_method(:now=) do |t|
##    Thread.current[:local_time] = t
##  end
##  
class Time
  def self.now
    ttime = Thread.current[:local_time]
    return ttime unless ttime.nil?
    Time.new
  end
  def self.now=(t)
    Thread.current[:local_time] = t
  end
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
  end

  describe 'timestamp lifecycle' do
    before do
      @klass = TimestampTestClass

      # Checks that our Time.now hack works
      the_now = Time.now
      Time.now = the_now
      _(Time.now).must_equal the_now
      Time.now = nil
      _(Time.now).wont_equal the_now
    end

    it 'updates timestamps with changes' do
      @backend = OrmMultipersist::NullBackend.new
      klass = @backend.client_for(@klass)
      obj = T.cast(klass.new, OrmMultipersist::EntityBase)

      the_now = Time.now
      Time.now = the_now
      obj.save!
      _(obj.send('created_at')).wont_be_nil
      _(obj.send('updated_at')).wont_be_nil
      _(obj.persisted?).must_equal true
      _(obj.send('created_at')).must_equal obj.send('updated_at')
      _(obj.send('created_at')).must_equal the_now

      # Now do update, make sure our time changes
      first_now = the_now
      the_now = Time.new
      Time.now = the_now
      obj.send('color=', 'red')
      _(obj.changed?).must_equal true
      obj.save!
      _(obj.changed?).must_equal false
      _(obj.changed?).must_equal false
      _(obj.send('created_at')).must_equal first_now
      _(obj.send('updated_at')).must_equal the_now

      final_now = the_now + 1
      Time.now = final_now
      obj.save!
      _(obj.send('created_at')).must_equal first_now
      _(obj.send('updated_at')).must_equal the_now  # no change

    end
  end
end

