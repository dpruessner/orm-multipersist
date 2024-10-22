require "active_model"

module OrmMultipersist
  #
  #
  # @!method multipersist_entity_klass
  #   @return [Class] The base class that the Entity is mixed into (short-cutting the Backend inheritance)
  #
  # @example Create a basic Person {Entity} as an Anonymous class (testing)
  #
  #     class Person
  #       include OrmMultipersist::Entity
  #
  #       persist_table_name 'persons'
  #       attribute :id, :integer, primary_key: true
  #       attribute :name, :string
  #     end
  #
  # @example Create a basic Person {Entity} as an Anonymous class (testing)
  #
  #     @person_klass = Class.new do
  #       include OrmMultipersist::Entity
  #
  #       # Name with '__' prefix to indicate anonymous and not in Namespace
  #       def self.name
  #         "__PersonKlass"
  #       end
  #
  #       persist_table_name 'persons'
  #       attribute :id, :integer, primary_key: true
  #       attribute :name, :string
  #
  #     end # Class.new(...) Peson
  #
  # @example Using the Person class with a persistence Backend
  #
  #     # Open the filename as an Sqlite3 database
  #     @backend = OrmMultipersist::SqliteBackend::new(@filename)
  #     # Create a class that is linked to Sqlite3 Backend persistence
  #     @person_klass = @backend[Person]
  #
  #     person = @person_klass.new(name: "Jenny")
  #     person.save!  #-> person.id is now populated by database auto_increment
  #
  #
  #
  module Entity
    # @!parse include ActiveModel::Model
    # @!parse include ActiveModel::Attributes
    # @!parse include ActiveModel::Dirty
    # @!parse include ActiveModel::Validations
    # @!parse extend ClassMethods
    # @!parse extend BackendExt

    def self.included(base)
      # Include the ActiveModel modules if they are not already included
      [
        ActiveModel::Model,
        ActiveModel::Attributes,
        ActiveModel::Dirty,
        ActiveModel::Validations,
        EntityBase
      ].each { |m| base.include(m) unless base.include?(m) }
    end
  end

  module EntityBase
    def self.included(base)
      # add in our ClassMethods
      base.extend(ClassMethods)

      # define the multipersist_attrs
      base.instance_variable_set(:@multipersist_attrs, {})
      base.define_singleton_method(:multipersist_attrs) do
        base.instance_variable_get(:@multipersist_attrs)
      end

      # define some lifecycle callbacks ()
      base.class_eval do
        define_model_callbacks :create
        define_model_callbacks :save
        define_model_callbacks :update
        define_model_callbacks :destroy
      end

      # define a resolver to get the base class that the Entity is mixed into (short-cutting the Backend inheritance)
      base.define_singleton_method(:multipersist_entity_klass) do
        base
      end

      # end of included()
    end

    def inspect
      attrs = self.class.attribute_names.map do |a|
        value = send(a)
        str_value = "[unknown]"
        if value.respond_to?(:inspect)
          str_value = value.inspect
        elsif value.respond_to?(:to_s)
          str_value = value.to_s
        elsif value.respond_to?(:name)
          str_value = "[#{value.class}:#{value.name}]"
        end
        str_value = "#{str_value[0..17]}...#{str_value[-10..]}" if str_value.size > 20
        "#{a}=#{str_value}"
      end
      "#<#{self.class.name} #{attrs.join(', ')}>"
    end

    # Check if record has been persisted to the back-end
    def persisted?
      multipersist_attr_get(:persisted) == true
    end

    # Check if record has not been persisted to the back-end (is a new record)
    #
    def new_record
      !persisted?
    end

    # Mark the record as persisted, which will also clear {ActiveModel::Dirty} changes
    def set_persisted
      multipersist_attr_set(:persisted, true)
      changes_applied
    end

    # Sets the PRIMARY KEY attribute to the value.  This looks up the primary key attribute name and sets that attribute to the value provided.
    def set_primary_key_attribute(value)
      raise "No primary key defined for #{self.class.name}" unless self.class.has_primary_key?
      send("#{self.class.get_primary_key}=", value)
    end

    private

    def multipersist_attr_get(name)
      instance_variable_get("@multipersist_#{name}")
    end

    def multipersist_attr_set(name, value)
      instance_variable_set("@multipersist_#{name}", value)
    end

    public

    # Save, but generate an exception if it is not validated
    def save!
      if persisted?
        run_callbacks :update do
          validate!
          return true unless changed?
          self.class.update_record(self)
        end
      else
        run_callbacks :save do
          validate!
          return true unless changed?
          self.class.create_record(self)
        end
      end
      set_persisted
      true
    end

    # Save, calling callbacks around lifecycle.
    #
    # @return [Boolean] true if the record was saved (or unchanged), false if invalid or not saved
    #
    def save
      return false unless valid?
      return true unless changed?
      if persisted?
        run_callbacks :update do
          return true unless changed?
          self.class.update_record(self)
        end
      else
        run_callbacks :save do
          return false unless valid?
          return true unless changed?
          self.class.create_record(self)
        end
      end
      set_persisted
      true
    end

    def destroy
      return false unless persisted?
      run_callbacks :destroy do
        self.class.destroy_record(self)
      end
    end

    # @!method multipersist_attrs
    #   Defines multipersist atributes for an ORM Type (eg, Hnsw::Vector)
    #
    #   @return [Hash] a hash of attributes that can be mutated during ORM Type definition and used later in persistence
    #
    module ClassMethods
      def attribute(name, type = nil, primary_key: false, **options)
        multipersist_attrs[:primary_key] = name if primary_key
        super(name, type, **options)
      end

      # Default handler for `client` that raises an execption.  Accessing persistence operations (create_record, destroy_record, ...)
      # without a Client connection will raise an exception.
      #
      # This method is *automatically* overriden in the entity-proxy Classes generated in the back-end Client instance.
      #
      def client
        raise "OrmMultiPersist::Entity is trying to access a persistence operation without a Client connection to a BackEnd"
      end

      # Sets the persistence table name
      def persist_table_name(name)
        multipersist_attrs[:table_name] = name
      end

      # Gets the persistance table name
      def table_name
        multipersist_attrs[:table_name]
      end

      # Gets the primary_key attribute in the persistence
      def get_primary_key
        multipersist_attrs[:primary_key]
      end

      # Check if the ORM Type has a PrimaryKey
      def has_primary_key?
        multipersist_attrs[:primary_key].nil? == false
      end

      # Pass the request thru to the client
      def create_record(record)
        client.create_record(record, self)
      end

      def update_record(record)
        client.update_record(record, self)
      end

      # Pass the destroy-record thru to the client, passing the record and our class to the function
      def destroy_record(record)
        client.destroy_record(record, self)
      end

      def ensure_table!
        client.ensure_table!(self)
      end

      # Return a recordset for the Entity that can be filtered, ordered, and limited
      def where(query)
        client.recordset(self).where(query)
      end

      # Return a recordset of all records for the Entity
      def all
        client.recordset(self)
      end

      def to_s
        "#<Class:#{name}>"
      end

      def inspect
        to_s
      end

      # Lookup a record by primary key
      # @return [Entity|nil] instance of the record, looked up by primary key
      def by_primary_key(value)
        raise "No primary key defined for #{name}" unless has_primary_key?
        client.lookup_by_primary_key(value, self)
      end
      alias_method :[], :by_primary_key

      def from_persistence(persist_hash)
        instance = new(persist_hash)
        instance.set_persisted
        instance
      end
    end
  end
end

require_relative 'type'
