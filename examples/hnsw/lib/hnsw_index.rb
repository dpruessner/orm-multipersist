require 'orm-multipersist'

module Hnsw
end

# Index to put vectors into an HNSW structure with a persistence back-end
class Hnsw::Index
  # Vector singleton class that is connected to the client back-end
  # @return [Class<Hnsw::Vector + OrmMultipersist::BackendExt>] the Vector class connected to a Client
  attr_reader :vector_klass

  # Initialize a new index with the given backend and options.
  # The backend must be an instance of OrmMultipersist::Backend.
  #
  # @param backend [OrmMultipersist::Backend] the backend to use
  # @param options [Hash] options for the index
  #
  def initialize(backend, options = {})
    @backend = backend
    raise ArugmentError, "Backend must be a valid ORM" unless @backend.is_a?(OrmMultipersist::Backend)
    @options = options
    
    @vector_klass = @backend[Hnsw::Vector]
  end



  def to_s
    "Hnsw::Index(@[#{@backend.client_klass_detail}];  options: #{@options})"
  end
end
