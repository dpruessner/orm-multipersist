# typed: true

module OrmMultipersist

  ## Mix-in to provide client/client_for relationship for Entities that persist into a Backend
  #
  # @example Create a **/dev/null** back-end
  #
  #    # Create a Backend that does nothing, but does implement the required interface.
  #    # Objects can be created and manipulated, but saving will do nothing.
  #    # Querying will return errors.
  #    #
  #    class DevNullBackend
  #      include OrmMultipersist::Backend
  #
  #      def create_record(record)
  #        # do nothing
  #      end
  #
  #      method_alias :update_record, :create_record
  #      method_alias :destroy_record, :create_record
  #    end
  #
  #    @backend = DevNullBackend.new
  #    vector = @backend[Vector].new(x: 1, y: 2)
  #    vector.save #-> will call DevNullBackend::create_record
  #
  #
  class Backend
    extend T::Sig
    extend T::Helpers
    include Kernel

    abstract!

    ## Get a Backend-connected child Class of klass that defines `#client` that points back to the Backend instance.
    #
    # Creates a new Klass that has singleton methods for persisting its records into this persistence layer.
    #
    # @param [Class] klass the ORM {Entity} class to connect to this Backend instance.
    # @return [Class] an {Entity} Class that inherits from `klass`` with singleton method to get a Backend instance
    #     for persisting its Entity records.
    #
    sig { params(klass: T.class_of(OrmMultipersist::Entity), ensure_table: T::Boolean).returns(T::Class[OrmMultipersist::Entity]) }
    def client_for(klass, ensure_table: false)
      @client_mapped ||= {}
      raise "cannot make Backend-connected class for non-Entity classes" unless klass.include? OrmMultipersist::Entity

      connected_klass = @client_mapped[klass]
      connected_klass = make_client_connected_klass(klass, ensure_table) if connected_klass.nil?
      return connected_klass
    end

    ## Same as {client_for} but ensures a table exists in the persistence
    sig { params(klass: T.class_of(OrmMultipersist::Entity)).returns(T.class_of(OrmMultipersist::Entity)) }
    def client_for!(klass)
      @client_mapped ||= {}
      raise "cannot make Backend-connected class for non-Entity classes" unless klass.include? OrmMultipersist::Entity

      connected_klass = @client_mapped[klass]
      if connected_klass.nil?
        connected_klass = make_client_connected_klass(klass, true)
      end
      return connected_klass
    end

    alias_method :[], :client_for

    private

    ## Makes an anonymous Class that will have `connected_klass.client() == this`.
    #
    # Includes in {BackendExt} methods into the {Entity} class to make a new *anonymous* class that
    # is connected to the {Backend} persistence layer.
    #
    # @param [Class<Entity>] class to derive a new *connected* type for
    # @param [Boolean] ensure_table if true, ensure that a table is created in the back-end for the Entity
    #
    # @return [Class<Entity+BackendExt>] Class that has {BackendExt} methods and is connected to this {Backend} for
    #     persisting `klass` {Entity} records.
    #
    sig { params(klass: T.class_of(OrmMultipersist::Entity), ensure_table: T::Boolean).returns(T.class_of(OrmMultipersist::Entity)) }
    def make_client_connected_klass(klass, ensure_table)
      this = self
      # Create a new Klass that has singleton methods for persisting its Type into this client.
      new_klass = Class.new(T.cast(klass, Class)) do
        define_singleton_method(:name) do
          T.bind(self, OrmMultipersist::EntityBase::ClassMethods)
          # get `name` from the ORM Type (not the ORM-Persistence Type)
          the_klass_detail = client.client_klass_detail
          if the_klass_detail.nil? || the_klass_detail.empty?
            klass.name
          else
            "#{klass.name}@#{the_klass_detail}[#{table_name}]"
          end
        end
        define_singleton_method(:client) do
          this
        end
      end

      @client_mapped[klass] = new_klass
      new_klass = T.cast(new_klass, T.all(OrmMultipersist::EntityBase::ClassMethods, T.class_of(OrmMultipersist::Entity)))
      new_klass.ensure_table! if ensure_table
      return new_klass
    end

    public

    # Create a record in the persistence layer.  This should update any primary-key or generated fields
    # and clear changes in the `record`.
    #
    # @abstract
    #
    sig { abstract.params(record: OrmMultipersist::EntityBase, orm_klass: T.class_of(OrmMultipersist::Entity)).void }
    def create_record(record, orm_klass); end

    # Updates a record already stored in the persistence layer.  Will only update {#changed} values.
    #
    #
    # @abstract
    #
    sig { abstract.params(record: OrmMultipersist::EntityBase, orm_klass: T.class_of(OrmMultipersist::Entity)).void }
    def update_record(record, orm_klass); end

    # Destroys a record already stored in the persistence layer.  Will destroy by `primary_key` if exists
    # or by all attributes in `record` otherwise.
    #
    # @abstract
    #
    sig { abstract.params(record: OrmMultipersist::EntityBase, orm_klass: T.class_of(OrmMultipersist::Entity)).void }
    def destroy_record(record, orm_klass); end

    ## Return one record by looking up by primary key value
    #
    # @return [Entity] Entity record of Class connected to {Backend}.
    #
    # @abstract
    #
    sig { abstract.params(value: T.untyped, entity_klass: T.class_of(OrmMultipersist::Entity)).returns(T.nilable(OrmMultipersist::Entity)) }
    def lookup_by_primary_key(value, entity_klass); end

    ## Return a recordset that can be ordered, filtered, limited and offset for a given Entity Class
    #
    #
    sig { abstract.params(entity_klass: T.class_of(OrmMultipersist::Entity)).returns(OrmMultipersist::Recordset) }
    def recordset(entity_klass); end

    ## Ensure that a table or store is created in the back-end
    #
    # @abstract
    #
    sig { abstract.params(entity_klass: T.class_of(OrmMultipersist::Entity)).void }
    def ensure_table!(entity_klass); end

    ## Overload this function to provide details to client-classes' #{inspect} to report details of the
    # persistence destination
    #
    # @return [String] a string that describes the client
    #
    def client_klass_detail
      ""
    end
  end

  module BackendExt
    # @!method client
    #   @return [Backend] the Backend instance that this Entity Class is connected to.
    #
    # @!method name
    #   Overload the Class name to include details of *where* the persistence of the Class is connected to.
    #   @return [String] the name of the Entity Class that is connected to the Backend instance.
  end
end
