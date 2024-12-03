module OrmMultipersist
  class Recordset
    ## Create an interface to a recordset
    #
    # @param [Backend] backend that provides persistence
    # @param [Class<Entity>] entity_klass class to create records for
    #
    def initialize(backend, entity_klass)
      unless backend.is_a?(OrmMultipersist::Backend)
        raise ArgumentError,
              "#{backend} must derive from OrmMultipersist::Backend"
      end
      unless entity_klass.is_a?(Class) && entity_klass.include?(OrmMultipersist::Entity)
        raise ArgumentError,
              "#{entity_klass} must include OrmMultipersist::Entity"
      end

      @backend = backend
      @entity_klass = entity_klass
      @table_name = entity_klass.table_name
      @limit = nil
      @order_by = []
      @project = nil
    end

    # Get the table name the recordset is referencing
    attr_reader :table_name

    # Update records in this recordset to set the values listed in `values`
    # @param [Hash] names and values to set to all records in the recordset
    #
    # @return [Integer] number of records affected
    # @abstract
    #
    def update(values)
      raise NotImplementedError, "#{self.class} must implement #update"
    end

    # Deletes the record in the persistence layer.  This will not call any hooks
    # for models.
    #
    # @return [Integer] number of records affected
    # @abstract
    #
    def delete!
      raise NotImplementedError, "#{self.class} must implement #delete!"
    end

    # Returns the number of records in the recordset
    # @return [Integer]
    # @abstract
    #
    def count
      raise NotImplementedError, "#{self.class} has not implemented #count"
    end

    # Yields a hash (that can be used by the {Entity} or {Backend} to create teh
    # appropriate record.
    #
    # @yield [record] iterates over each record that matches
    # @yieldparam [Entity] one entity; one row
    #
    # @abstract
    #
    def each(&blk)
      raise NotImplementedError, "#{self.class} has not implemented #each"
    end

    def map(&blk)
      each.map(&blk)
    end

    # Returns all records in the recordset as an array
    #
    # @return [Array<Hash>] all records in the recordset
    #
    # @abstract
    def all
      raise NotImplementedError, "#{self.class} has not implemented #all"
    end

    # Returns an Array of records. NOTE: this will evaluate the lazy query
    def to_a
      raise NotImplementedError, "#{self.class} has not implemented #to_a"
    end

    # Returns the first record in the recordset
    #
    def first
      raise NotImplementedError, "#{self.class} has not implemented #first"
    end

    # Reduces the dataset to records that also match these values
    #
    # @return [Recordset]
    def and(cond)
      raise NotImplementedError, "#{self.class} must implement #and"
    end

    def where(cond)
      self.and(cond)
    end

    # Expands dataset to also include records matching condition
    #
    # @return [Recordset]
    def or(cond)
      raise NotImplementedError, "#{self.class} must implement #or"
    end

    # Sets the ordering of the dataset
    #
    # @param [String|Symbol|Hash<String|Symbol,Integer>|Array<[name, Integer]>] order the recordset. 1 is ascending,
    # -1 is descending
    #
    # @return [Recordset]
    #
    # @abstract
    #
    def order_by(order = {}, *args, **kwarg)
      raise NotImplementedError, "#{self.class} must implement #order_by"
    end

    # Limit the records to a specific number of items
    #
    # @return [Recordset]
    #
    def limit(count)
      @limit = limit
      self
    end

    # Offset the returned records within the possible dataset
    #
    # @return [Recordset]
    def offset(value)
      @offset = value
      self
    end

    # Select only specific attributes to pull from back-end and
    # populate into the Entity.  NOTE: this may cause entity validation to fail
    # if required fields are not populated.
    #
    # @param [Array] names attribute names to select
    # @return self
    #
    def project(*names)
      return if names.empty?
      @project ||= []
      @project.append(*names.map{ |v| v.to_s })
      @project.uniq!
      self
    end

    # Resets the projection to all attributes
    # @return self
    def project_all
      @project = nil
      self
    end

    private

    def limit_count
      @limit
    end

    # Cast a record (Hash) into a record (Entity)
    #
    # @param [Hash] record_hash
    # @return [Entity]
    #
    def cast_as_entity(record_hash)
      # Refine down only to the projected fields
      record = record_hash.dup
      record.select! { |k, _v| @project.member?(k.to_s) } if @project
      @entity_klass.new(record)
    end
  end
end
