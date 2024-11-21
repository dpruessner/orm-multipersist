# typed: true

require "active_model"
require 'active_support/concern'

require 'sorbet-runtime'

# Error to indicate the record is invalid in some way and that the record.errors should be checked
# (**note**: `record.valid?` will clear the errors, so this error is useful to indicate that the record is invalid)
#
class OrmMultipersist::RecordInvalid < StandardError; end

module OrmMultipersist
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
  module Entity
    extend T::Sig
    extend T::Helpers

    #requires_ancestor { ActiveModel::Model }
    #requires_ancestor { ActiveModel::Attributes }
    #requires_ancestor { T.class_of(ActiveModel::Attributes::ClassMethods) }
    requires_ancestor { ActiveModel::API }
    requires_ancestor { ActiveModel::Dirty }
    requires_ancestor { ActiveModel::Validations }
    requires_ancestor { T.class_of(Object) }
    


    # @!parse include ActiveModel::Model
    # @!parse include ActiveModel::Attributes
    # @!parse include ActiveModel::Dirty
    # @!parse include ActiveModel::Validations
    # @!parse extend ClassMethods
    # @!parse extend BackendExt


    def self.included(base)
      base.include(ActiveModel::Model)
      base.include(ActiveModel::Attributes)
      base.include(ActiveModel::Dirty)
      base.include(ActiveModel::Validations)
      # add in our ClassMethods
      base.extend(ClassMethods)
      base.prepend(self)

      # define the multipersist_attrs
      base.instance_variable_set(:@multipersist_attrs, {})
      base.define_singleton_method(:multipersist_attrs) do
        base.instance_variable_get(:@multipersist_attrs)
      end


      # define some lifecycle callbacks ()
      T.cast(base, T.class_of(ActiveModel::Validations)).class_eval do
        define_model_callbacks :create
        define_model_callbacks :save
        define_model_callbacks :update
        define_model_callbacks :destroy
        define_singleton_method(:multipersist_entity_klass) do
          base
        end
        define_singleton_method(:multipersist_entity_root?) do
          self.__id__ == base.__id__
        end
      end

    end

    sig { returns(String) }
    def inspect
      attrs = T.cast(self.class, ActiveModel::Attributes::ClassMethods).attribute_names.map do |a|
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

    # Assign the **primary key** _attribute_ a value.
    # Looks up the primary key _attribute_ name and sets that attribute to the provided value.
    #
    # @raises [RuntimeError] if the Entity does not have {primary_key?}
    #
    def assign_primary_key_attribute(value)
      klass = T.cast(self.class, ClassMethods)
      klass.primary_key?
      raise "No primary key defined for #{klass.name}" unless klass.primary_key?
      send("#{klass.primary_key}=", value)
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
          T.cast(self.class, Entity::ClassMethods).update_record(self)
        end
      else
        run_callbacks :save do
          validate!
          return true unless changed?
          T.cast(self.class, Entity::ClassMethods).create_record(self)
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
      klass = T.cast(self.class, Entity::ClassMethods)

      return false unless valid?
      return true unless changed?
      if persisted?
        run_callbacks :update do
          return true unless changed?
          klass.update_record(self)
        end
      else
        run_callbacks :save do
          return false unless valid?
          return true unless changed?
          begin
            klass.create_record(self)
          rescue RecordInvalid => _e
            # skip setting persisted; record.errors will be set
            return false
          end
        end
      end
      set_persisted
      true
    end

    def destroy
      return false unless persisted?
      run_callbacks :destroy do
        T.cast(self.class, Entity::ClassMethods).destroy_record(self)
      end
    end

    # @!method multipersist_attrs
    #   Defines multipersist atributes for an ORM Type (eg, Hnsw::Vector)
    #
    #   @return [Hash] a hash of attributes that can be mutated during ORM Type definition and used later in persistence
    #
    module ClassMethods
      extend T::Sig
      extend T::Helpers

      #def self.extended(base)
      #end

      requires_ancestor { Kernel }
      requires_ancestor { T.class_of(ActiveModel::API) }

      def multipersist_attrs
        raise RuntimeError, "multipersist_attrs should be defined when the Entity creates the Entity-Base link (see Entity::included)"
      end

      # Define an attribute for the Entity
      #
      # ## Options
      #
      # * `:primary_key` - indicate attribute is the primary key for the ORM Type (and will likely have a persistence-assigned value)
      # * `:unique` - indicate attribute is unique in the persistence (will likely create an index in the persistence to enforce uniqueness)
      #
      def attribute(name, type = nil, **options)
        if options[:primary_key]
          multipersist_attrs[:primary_key] = name
          options.delete(:primary_key)
        end
        if options[:not_null]
          multipersist_attrs[:not_null_attributes] ||= []
          multipersist_attrs[:not_null_attributes] << name
          options.delete(:not_null)
          # add in validation for nut_null
          validates_presence_of name
        end
        if options[:unique]
          multipersist_attrs[:unique_attributes] ||= []
          multipersist_attrs[:unique_attributes] << name
          options.delete(:unique)
        end
        if options[:index]
          multipersist_attrs[:indexes] ||= []
          multipersist_attrs[:indexes] << name
          options.delete(:index)
        end
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
      def primary_key
        multipersist_attrs[:primary_key]
      end

      # Check if the ORM Type has a PrimaryKey
      def primary_key?
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

      # Lookup a record by primary key
      # @return [Entity|nil] instance of the record, looked up by primary key
      def by_primary_key(value)
        raise "No primary key defined for #{name}" unless primary_key?
        client.lookup_by_primary_key(value, self)
      end
      alias_method :[], :by_primary_key

      sig { params(persist_hash: Hash).returns(Entity) }
      def from_persistence(persist_hash)
        instance = T.cast(self, T.all(
                                  T::Class[ActiveModel::API],
                                  T::Class[Entity]
                                )).new(persist_hash)
        instance.set_persisted
        instance
      end
    end

    # Entity::ClassMethods
    mixes_in_class_methods(ClassMethods)
    #mixes_in_class_methods(ActiveModel::Attributes::ClassMethods)
    #mixes_in_class_methods(ActiveModel::Validations::ClassMethods)
  end
end

require_relative 'type'

