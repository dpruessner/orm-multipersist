require 'minitest/autorun'
require 'minitest/expectations'
require 'orm-multipersist'
require_relative 'test_helpers'

describe OrmMultipersist::Entity do
  before do
    @klass = Class.new do
      include OrmMultipersist::Entity

      attribute :id, :integer, primary_key: true
      attribute :color, :string


      def self.anonymous_class?
        true
      end
      def self.name
        "AnonymousTestClass"
      end
    end
  end

  it 'instantiates' do
    entity = @klass.new
    _(entity).wont_be_nil
  end

  it 'has a settable id' do
    entity = @klass.new
    _(entity).must_respond_to(:id)
    _(entity).must_respond_to(:id=)

    entity.id = 100
    _(entity.id).must_equal 100
  end

  it 'tracks changes of an attribute' do
    entity = @klass.new
    entity.id = 100
    _(entity.changes).must_equal({"id" => [nil, 100]})
    entity.id = 200
    _(entity.changes).must_equal({"id" => [nil, 200]})
  end

  it 'tracks persistence' do
    entity = @klass.new
    entity.id = 100
    _(entity.persisted?).must_equal false
    entity.set_persisted
    _(entity.persisted?).must_equal true
  end


  it 'can have the primary_key set' do
    entity = @klass.new
    entity.assign_primary_key_attribute(30)
    _(entity.id).must_equal 30
  end

  it 'can be created by a hash' do
    entity = @klass.new(id: 10, color: 'red')
    _(entity.id).must_equal 10
    _(entity.color).must_equal 'red'
    _(entity.changes).must_equal({"id" => [nil, 10], "color" => [nil, "red"]})
  end

  it 'has classmethod identifying primary key' do
    _(@klass.primary_key?).must_equal true
    _(@klass.primary_key).must_equal :id
  end

end

