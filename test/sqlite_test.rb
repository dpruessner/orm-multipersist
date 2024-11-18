require 'minitest/autorun'
require 'minitest/expectations'
require 'orm-multipersist'
require 'orm-multipersist/sqlite'
require_relative 'test_helpers'

require 'pry' ## TODO-PRODUCTION-FAIL: remove pry

def add_db_logging(db)
  require "logger"
  db.sql_log_level = :debug
  db.loggers << Logger.new($stdout)
end

describe OrmMultipersist::SqliteBackend do
  describe "with primary key" do

    before do
      @person_klass = Class.new do
        include OrmMultipersist::Entity
        def self.name
          "__PersonKlass"
        end
        def self.inspect
          "#<Class:#{self.name}>"
        end

        persist_table_name 'persons'
        attribute :id, :integer, primary_key: true
        attribute :name, :string

      end # Class.new(...) preson
      @filename = "/tmp/sqlite_test-#{rand(36**8).to_s(36)}.sqlite"
      #puts "DB=#{@filename}"
      @client = OrmMultipersist::SqliteBackend::new(@filename)
    end

    # Cleanup
    after do
      #puts "Unlinking #{@filename}"
      File.unlink(@filename)
    end

    it "creates a client" do
      _(@person_klass).wont_be_nil
      _(@client).wont_be_nil
      db = @client.db
      _(db).wont_be_nil
    end

    it "provides a Backend-connected Class" do
      _(@client).wont_be_nil
      persisted_person_klass = @client[@person_klass]
      _(persisted_person_klass).wont_be_nil
      person = persisted_person_klass.new
      _(person.class.ancestors).must_include @person_klass

      _(@person_klass.name).must_equal "__PersonKlass"
      _(persisted_person_klass.name).wont_be_nil
    end

    it "creates tables" do
      db = @client.db
      person_klass = @client[@person_klass]
      person_klass.ensure_table!
      _(db.schema :persons).wont_be_nil
    end

    it "persists a Backend-connected Entity record" do
      db = @client.db
      person_klass = @client[@person_klass]
      person_klass.ensure_table!

      person = person_klass.new(name: 'George')
      _(person.persisted?).must_equal false
      #puts "Saving to Persistence #{person_klass}"
      _(person.save).must_equal true
      _(person.id).wont_be_nil
      _(person.persisted?).must_equal true

      # Check that record is saved by directly querying database
      results = db[:persons].all
      _(results.size).must_equal 1
      _(results.first[:id]).must_equal 1
      _(results.first[:name]).must_equal "George"
    end

    it "updates a saved Backeend-connected Entity record" do
      db = @client.db
      person_klass = @client[@person_klass]
      person_klass.ensure_table!

      person = person_klass.new(name: 'George')
      _(person.save).must_equal true
      _(person.persisted?).must_equal true

      # Check that record is saved by directly querying database
      results = db[:persons].all
      _(results.size).must_equal 1
      _(results.first[:id]).must_equal 1
      _(results.first[:name]).must_equal "George"
      #
      # Perform update
      person.name = "Emily"
      _(person.changes).wont_be_nil
      _(person.changes).wont_be :empty?
      _(person.save).must_equal true
      _(person.id).must_equal 1

      # Check results from DB
      results = db[:persons].all
      _(results.size).must_equal 1
      _(results.first[:id]).must_equal 1
      _(results.first[:name]).must_equal "Emily"
    end

    it "looks up record by primary key" do
      person_klass = @client[@person_klass]
      person_klass.ensure_table!

      person = person_klass.new(name: 'George')
      person.save!
      person_id = person.id   # save off our newly inserted ID

      person = nil
      person = person_klass[person_id]
      _(person).wont_be_nil
      _(person.name).must_equal 'George'
      _(person.persisted?).must_equal true
      _(person.changed?).must_equal false
    end

    it "fails to store a record with a non-null field missing" do
      # reopen the class and add a unique attribute
      @person_klass.class_eval do
        attribute :email, :string, not_null: true
      end
      person_klass = @client.client_for!(@person_klass) # ensure table and indexes exist
      person = person_klass.new(name: 'George').tap{|e| e.save }
      _(person.persisted?).must_equal false
      _(person.id).must_be_nil
      _(person.errors).wont_be_nil
      _(person.errors).wont_be :empty?
      _(person.errors[:email]).wont_be_nil
    end

    it "creates a record with a unique attribute" do 
      # reopen the class and add a unique attribute
      @person_klass.class_eval do
        attribute :email, :string, unique: true, not_null: true
      end
      person_klass = @client.client_for!(@person_klass) # ensure table and indexes exist
      person = person_klass.new(name: 'Linda', email: 'email@zzz').tap{|e| e.save }
      _(person.persisted?).must_equal true
      _(person.id).wont_be_nil

      # Try to create a duplicate
      person = person_klass.new(name: 'Jao', email: 'email@zzz')
      person.save
      _(person.persisted?).must_equal false
      _(person.errors).wont_be_nil
      _(person.errors).wont_be :empty?
      _(person.errors[:email]).wont_be_nil
      _(person.id).must_be_nil
    end

  end # with primary key


#####
# No Primary Keys

  describe "with no primary_key" do
    before do
      @item_klass = Class.new do
        include OrmMultipersist::Entity
        def self.name
          "__Items"
        end
        def self.inspect
          "#<Class:#{self.name}>"
        end

        persist_table_name 'items'
        attribute :name, :string
        attribute :description, :string
        attribute :value, :integer

      end # Class.new(...) preson
      @filename = "/tmp/sqlite_test-#{rand(36**8).to_s(36)}.sqlite"
      #puts "DB=#{@filename}"
      @client = OrmMultipersist::SqliteBackend::new(@filename)
    end
    # Cleanup
    after do
      #puts "Unlinking #{@filename}"
      File.unlink(@filename)
    end

    it "creates tables" do
      db = @client.db
      item_klass = @client[@item_klass]
      item_klass.ensure_table!
      _(db.schema :items).wont_be_nil
    end

    it "creates an item" do
      item_klass = @client[@item_klass]
      item_klass.ensure_table!

      item = item_klass.new(name: 'chair')
      _(item.persisted?).must_equal false
      _(item.save).must_equal true
      _(item.persisted?).must_equal true
    end

    it "updates an item" do
      db = @client.db
      #add_db_logging(db)

      item_klass = @client[@item_klass]
      item_klass.ensure_table!

      item = item_klass.new(name: 'chair', description: 'desc', value: 100)
      _(item.persisted?).must_equal false
      #puts "Saving to Persistence #{item_klass}"
      _(item.save).must_equal true
      _(item.persisted?).must_equal true

      # Change two parameters
      item.description = "new description"
      _(item.persisted?).must_equal true
      _(item.changed?).must_equal true
      _(item.save).must_equal true
      _(item.changed?).must_equal false

      result = db[:items].to_a
      _(result.size).must_equal 1
      _(result[0]).must_equal({name: 'chair', description: 'new description', value: 100})
    end
  end
end

describe OrmMultipersist::SqliteBackend::SqliteRecordset do
  before do
    @person_klass = Class.new do
      include OrmMultipersist::Entity
      def self.name
        "__PersonKlass"
      end
      def self.inspect
        "#<Class:#{self.name}>"
      end

      persist_table_name 'persons'
      attribute :id, :integer, primary_key: true
      attribute :name, :string
      attribute :age, :integer
      attribute :telephone, :string
      attribute :zipcode, :string
      attribute :city, :string

    end # Class.new(...) preson
    @filename = "/tmp/sqlite_test-#{rand(36**8).to_s(36)}.sqlite"
    @client = OrmMultipersist::SqliteBackend::new(@filename)
  end
  after do
    File.unlink(@filename)
  end

  it "creates a recordset" do
    _recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
  end

  it "limits" do
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.limit(100)
    _(recordset.dataset.sql).must_match(/LIMIT 100/)
  end
  it "offsets" do
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.offset(30)
    _(recordset.dataset.sql).must_match(/OFFSET 30/)
  end
  it "limits and offsets " do
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.limit(100)
    recordset.offset(30)
    _(recordset.dataset.sql).must_match(/LIMIT 100.*OFFSET 30/)
  end

  it "returns an array of hashes for records" do
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    # Create the record while ensureing the table exists ({#client_for!})
    person = @client.client_for!(@person_klass).new(name: 'George', age: 50, telephone: '555-1212', zipcode: '98101', city: 'Seattle')
    person.save
    # Make sure it saved correclty
    dataset = @client.db[:persons]
    _(dataset.count).must_equal 1

    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    record_ary = recordset.each.to_a
    _(record_ary.size).must_equal 1
  end


  it "has where accept key-value" do
    person_klass = @client.client_for!(@person_klass)
    _person = person_klass.new(name: 'George', age: 50, telephone: '555-1212', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Margret', age: 20, telephone: '555-1111', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Bill', age: 20, telephone: '555-2222', zipcode: '98101', city: 'Seattle').tap{|e| e.save }

    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    _(recordset.count).must_equal 3

    recordset.and(name: 'George')
    _(recordset.all.size).must_equal 1

    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.and(age: 20)
    _(recordset.count).must_equal 2

    recordset.and(name: 'Margret')
    _(recordset.count).must_equal 1

    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.and(age: 20, name: 'Margret')
    _(recordset.count).must_equal 1
    _(recordset.first.name).must_equal 'Margret'
  end

  it "orders by field" do
    person_klass = @client.client_for!(@person_klass)
    _person = person_klass.new(name: 'George', age: 50, telephone: '555-1000', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Margret', age: 20, telephone: '555-1111', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Bill', age: 20, telephone: '555-2222', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Belinda', age: 23, telephone: '555-0222', zipcode: '98101', city: 'Seattle').tap{|e| e.save }

    # Ordering 1
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    _(recordset.count).must_equal 4
    recordset.order_by(:telephone)
    _(recordset.first.name).must_equal 'Belinda'

    # Ordering 2
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.order_by(:age, :name)
    _(recordset.map{|v| v.name}.to_a).must_equal ['Bill', 'Margret', 'Belinda', 'George']

    # Ordering 3 (same as ordering 2, broken apart)
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.order_by(:age)
    recordset.order_by(name: 1)
    _(recordset.map{|v| v.name}.to_a).must_equal ['Bill', 'Margret', 'Belinda', 'George']

    # Ordering 4 (moves age to end-of-queue)
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.order_by(:age)
    recordset.order_by(name: 1)
    recordset.order_by(:age)
    _(recordset.map{|v| v.name}.to_a).must_equal ['Belinda', 'Bill', 'George', 'Margret']

    # Ordering 5 (same as 3)
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.order_by(age: 1, name: 1)
    _(recordset.map{|v| v.name}.to_a).must_equal ['Bill', 'Margret', 'Belinda', 'George']

    # Ordering 6 (same as 4)
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.order_by(name: 1, age: 1)
    _(recordset.map{|v| v.name}.to_a).must_equal ['Belinda', 'Bill', 'George', 'Margret']

  end
  it "filters with field comparison operators" do
    person_klass = @client.client_for!(@person_klass)
    _person = person_klass.new(name: 'George', age: 50, telephone: '555-1000', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Margret', age: 20, telephone: '555-1111', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Bill', age: 20, telephone: '555-2222', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Belinda', age: 23, telephone: '555-0222', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Harry', age: 19, telephone: '555-0222', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Xavier', age: 79, telephone: '555-0222', zipcode: '48127', city: 'Detroit').tap{|e| e.save }

    # Check number of records
    _(person_klass.client.db.dataset.from(person_klass.table_name).count).must_equal 6

    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    _(recordset.and(age: {'$gt' => 22}).map{|v| v.name}).must_equal ['George', 'Belinda', 'Xavier']

    # Results 1
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.and(age: {'$gt' => 22}, city: 'Seattle')
    recordset.or(age: 19)
    _(recordset.map{|v| v.name}).must_equal ['George', 'Belinda', 'Harry']

    # Results 2 (same as 1)
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.and(age: {'$gt' => 22}, city: 'Seattle')
    recordset.or(age: 19)
    #puts "SQL: #{recordset.dataset.sql}"
    _(recordset.map{|v| v.name}).must_equal ['George', 'Belinda', 'Harry']
    
    # Results 3 (same as 1)
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.and(age: {'$gt' => 22}, city: 'Seattle')
    recordset.or(age: 19)
    #puts "SQL: #{recordset.dataset.sql}"
    _(recordset.map{|v| v.name}).must_equal ['George', 'Belinda', 'Harry']

    # Results 4 (same as 1)
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.where('$or' => [
                   { age: {'$gt' => 22}, city: 'Seattle'},
                   { age: 19 }])
    #puts "SQL: #{recordset.dataset.sql}"
    _(recordset.map{|v| v.name}).must_equal ['George', 'Belinda', 'Harry']
  end

  it "handles nested boolean expressions" do
    person_klass = @client.client_for!(@person_klass)
    _person = person_klass.new(name: 'George', age: 50, telephone: '555-1000', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Margret', age: 20, telephone: '555-1111', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Bill', age: 20, telephone: '555-2222', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Belinda', age: 23, telephone: '555-0222', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Harry', age: 19, telephone: '555-0222', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Xavier', age: 79, telephone: '555-0222', zipcode: '48127', city: 'Detroit').tap{|e| e.save }

    # Results 4 (same as 1)
    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.where(age: {'$gt' => 22}, city: 'Seattle', '$or' => [
      {age: 19, name: 'Harry'},
      {age: 23, name: 'Belinda'},
      {name: 'George'}
    ])
    #puts "SQL: #{recordset.dataset.sql}"
    _(recordset.map{|v| v.name}).must_equal ['George', 'Belinda']

    recordset = OrmMultipersist::SqliteBackend::SqliteRecordset.new(@client, @person_klass)
    recordset.where(age: 50)
    recordset.or(age: 20)
    recordset.and(city: 'Seattle')
    #puts "SQL: #{recordset.dataset.sql}"
    _(recordset.map{|v| v.name}).must_equal ['George', 'Margret', 'Bill']
  end

  it "raises when not connected to backend" do
    _ { @person_klass.all }.must_raise RuntimeError
  end

  it "provides an ALL recordset" do
    person_klass = @client.client_for!(@person_klass)
    _person = person_klass.new(name: 'George', age: 50, telephone: '555-1000', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Margret', age: 20, telephone: '555-1111', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Bill', age: 20, telephone: '555-2222', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Belinda', age: 23, telephone: '555-0222', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Harry', age: 19, telephone: '555-0222', zipcode: '98101', city: 'Seattle').tap{|e| e.save }
    _person = person_klass.new(name: 'Xavier', age: 79, telephone: '555-0222', zipcode: '48127', city: 'Detroit').tap{|e| e.save }
    recordset = person_klass.all
    _(recordset).must_be_kind_of OrmMultipersist::Recordset
    _(recordset.count).must_equal 6
    _(recordset.map{|v| v.name}).must_equal ['George', 'Margret', 'Bill', 'Belinda', 'Harry', 'Xavier']
  end


end

