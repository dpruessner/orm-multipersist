module OrmMultipersist
  ## Mix-in to provide client/client_for relationship for Entities that persist into a Backend
  #
  # @example Create a **/dev/null** back-end
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
  module Backend
    ## Get a Backend-connected child Class of Klass that defines `#client` that points back to the Backend instance.
    #
    # Creates a new Klass that has singleton methods for persisting its Type into this client.
    #
    # @param [Class] klass the ORM {Entity} Class to connect to this Backend instance.
    # @return [Class] an {Entity} Class that inherits from `klass`` with singleton method to get a Backend instance for persisting its Entity records.
    #
    def client_for(klass)
      @client_mapped ||= {}
      raise "cannot make Backend-connected class for non-Entity classes" unless klass.is_a? OrmMultipersist::Entity

      connected_klass = @client_mapped[klass]
      connected_klass = make_client_connected_klass(klass) if connected_klass.nil?
      return connected_klass
    end

    alias_method :[], :client_for

    private

    ## Makes an anonymous Class that will have ConnectedKlass.client() #=> this
    def make_client_connected_klass(klass)
      this = self
      # Create a new Klass that has singleton methods for persisting its Type into this client.
      new_klass = Class.new(klass) do
        define_singleton_method(:name) do
          # get `name` from the ORM Type (not the ORM-Persistence Type)
          klass.name
        end

        define_singleton_method(:client) do
          this
        end
      end
      @client_mapped[klass] = new_klass
      return new_klass
    end

    public

    def create_record(record, orm_klass)
      raise NotImplementedError, "create_record must be implemented in #{self.class}"
    end

    def update_record(record, orm_klass)
      raise NotImplementedError, "update_record must be implemented in #{self.class}"
    end

    def destroy_record(record, orm_klass)
      raise NotImplementedError, "destroy_record must be implemented in #{self.class}"
    end

    # TODO: implement reading/listing of records in a "thoughtful" way.

    ## Overload this function to provide details to client-classes' #{inspect} to report details of the persistence destination
    #
    # @return [String] a string that describes the client
    #
    def client_klass_detail
      ""
    end
  end
end
