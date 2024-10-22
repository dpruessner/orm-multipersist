require 'orm-multipersist'

module Hnsw
end

class Hnsw::Vector
  include OrmMultipersist::Entity

  attribute :vector, Binary
  attribute :level, Integer
  attribute :id, Integer, primary_key: true

  def vector_array
    vector.unpack('f*')
  end

  def vector_array=(array)
    self.vector = array.pack('f*')
  end

  # Calculate the dot product of this vector with another vector
  #
  # @param [Array] ary The vector array (if available, to optimize for performance)
  def magnitude(ary = nil)
    ary ||= vector_array
    Math.sqrt(ary.map { |x| x**2 }.sum)
  end

  # Mutate and normalize the vector to have a magnitude of 1
  def normalize!
    ary = vector_array
    mag = magnitude(ary)
    self.vector_array = ary.map { |x| x / mag }
  end

  # Calculates the cosine similarity between this vector and another vector
  def distance_csim(other)
    ary_a = vector_array
    ary_b = other.vector_array

    raise ArgumentError, "Vector sizes do not match (#{ary_a.size} != #{ary_b.size})" if ary_a.size != ary_b.size

    # calculate dot product
    dot_product = ary_a.zip(ary_b).map { |a, b| a * b }.sum

    # calculate magnitudes
    mag_a = magnitude(ary_a)
    mag_b = other.magnitude(ary_b)

    # calculate cosine similarity
    dot_product / (mag_a * mag_b)
  end

  # Creates a random vector of the specified dimension of unity magnitude
  def self.random(dimension = 512)
    vector = Array.new(dimension) { rand(-1.0..1.0) }
    vector = vector.map { |x| x / vector.magnitude }
    new(vector_array: vector)
  end
end
