require "active_model"

module OrmMultipersist
  #
  # !!method multipersist_entity_klass
  #   @return [Class] The base class that the Entity is mixed into (short-cutting the Backend inheritance)
  #
  module Entity
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
      def set_table(name)
        mulitpersist_attrs[:table_name] = name
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
    end
  end
end
