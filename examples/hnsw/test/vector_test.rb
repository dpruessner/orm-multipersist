require_relative 'test_helpers'

require 'vector'

describe Hnsw::Vector do
  it "can be created" do
    vec = Hnsw::Vector.new
    _(vec).must_be_instance_of Hnsw::Vector
  end
  it "can be created with a vector_array" do
    vec = Hnsw::Vector.new(vector_array: [1, 2, 3])
    _(vec).must_be_instance_of Hnsw::Vector
    _(vec.vector_array).must_equal [1, 2, 3]
    _(vec.dimension).must_equal 3
  end
  it "can be created with binary vector data" do
    vec = Hnsw::Vector.new(vector: [1, 2, 3].pack("f*"))
    _(vec).must_be_instance_of Hnsw::Vector
    _(vec.dimension).must_equal 3
    _(vec.vector).must_equal [1, 2, 3].pack("f*")
    _(vec.vector_array).must_equal [1.0, 2.0, 3.0]
  end
  it "will normalize" do
    vec = Hnsw::Vector.new(vector_array: [1, 2, 3])
    _(vec.normalize!).must_be_instance_of Hnsw::Vector
    _(vec.magnitude).must_be_within_epsilon 1.0, 1e-8
  end
  it "raises argument error on basis with index exceeding dimension" do
    _ { Hnsw::Vector.basis(4, 3) }.must_raise ArgumentError
  end
  it "creates a basis vector" do
    vec = Hnsw::Vector.basis(1, 3)
    _(vec).must_be_instance_of Hnsw::Vector
    _(vec.vector_array).must_equal [0, 1, 0]
    _(vec.dimension).must_equal 3
    _(vec.magnitude).must_be_within_epsilon 1.0, 1e-8
  end
  it "creates a random vector of unity magnitude" do
    vec = Hnsw::Vector.random(3)
    _(vec).must_be_instance_of Hnsw::Vector
    _(vec.dimension).must_equal 3
    _(vec.magnitude).must_be_within_epsilon 1.0, 1e-7

    # With high dimensionality
    vec = Hnsw::Vector.random(1000)
    _(vec).must_be_instance_of Hnsw::Vector
    _(vec.dimension).must_equal 1000
    _(vec.magnitude).must_be_within_epsilon 1.0, 1e-7
  end
  it "can measure cosine similarity" do
    vec1 = Hnsw::Vector.new(vector_array: [1, 2, 3])
    vec2 = Hnsw::Vector.new(vector_array: [1, 1, 1])
    _(vec1.distance_csim(vec2)).must_be_within_epsilon 0.9258200997725514, 1e-6
  end
end
