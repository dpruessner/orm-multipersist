# typed: true
#
require_relative 'entity'
require_relative 'backend'

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
  class NullBackend < OrmMultipersist::Backend
    extend T::Sig

    # Create a record in the persistence layer.  This should update any primary-key or generated fields
    # and clear changes in the `record`.
    #
    # @abstract
    #
    sig { override.params(record: EntityBase, _orm_klass: T.class_of(Entity)).void }
    def create_record(record, _orm_klass)
      record.set_persisted
      nil
    end

    # Updates a record already stored in the persistence layer.  Will only update {#changed} values.
    #
    #
    # @abstract
    #
    sig { override.params(record: EntityBase, _orm_klass: T.class_of(Entity)).void }
    def update_record(record, _orm_klass)
      record.set_persisted
      nil
    end

    # Destroys a record already stored in the persistence layer.  Will destroy by `primary_key` if exists
    # or by all attributes in `record` otherwise.
    #
    # @abstract
    #
    # rubocop:disable Lint/UnusedMethodArgument
    sig { override.params(record: EntityBase, _orm_klass: T.class_of(Entity)).void }
    def destroy_record(record, _orm_klass)
      nil
    end
    # rubocop:enable Lint/UnusedMethodArgument

    ## Return one record by looking up by primary key value
    #
    # @return [Entity] Entity record of Class connected to {Backend}.
    #
    # @abstract
    #
    def lookup_by_primary_key(value, entity_klass)
      raise NotImplementedError, "lookup_by_primary_key must be implemented in #{self.class.name}"
    end

    ## Return a recordset that can be ordered, filtered, limited and offset for a given Entity Class
    #
    #
    def recordset(entity_klass)
      raise NotImplementedError, "recordset must be implemented in #{self.class.name}"
    end

    ## Ensure that a table or store is created in the back-end
    #
    # @abstract
    #
    def ensure_table!(entity_klass)
      raise NotImplementedError, "ensure_table! must be implemented in #{self.class.name}"
    end

    ## Overload this function to provide details to client-classes' #{inspect} to report details of the
    # persistence destination
    #
    # @return [String] a string that describes the client
    #
    def client_klass_detail
      "NULL"
    end
  end
end
