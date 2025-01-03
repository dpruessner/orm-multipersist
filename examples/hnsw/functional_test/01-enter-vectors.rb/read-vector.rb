#!/usr/bin/env ruby
require 'pry'
$LOAD_PATH.push(File.expand_path("../../lib", File.dirname(__FILE__)))

unless File.exist?('output/test.sqlite3')
  puts "Need to run 'bundle exec ruby enter-vectors' first"
  exit 1
end

class Array
  # Return a new array with the same direction, but with a magnitude of 1
  def normalize
    mag = Math.sqrt(inject(0) { |sum, x| sum + x**2 })
    map { |x| x / mag }
  end

  def self.random(dimension)
    Array.new(dimension) { rand(-1.0..1.0) }
  end
end

def random_unit_vector(dimension)
  Array.random(dimension).normalize
end

require 'vector'
require 'hnsw_index'
require 'orm-multipersist/sqlite'

vector_dimension = 2
epoch = Time.now.to_i

client = OrmMultipersist::SqliteBackend.new('output/test.sqlite3')
Vector = client[Hnsw::Vector]

index = Hnsw::Index.new(client)
puts "Created index (#{index})..."

RECORD_COUNT = 100_000

# Add 1000 random vectors, tracking the epoch
# RECORD_COUNT.times do |i|
#   vector_array = random_unit_vector(vector_dimension)
#   index.add(vector_array, "#{epoch}:#{i}")
# end

puts "Creating #{RECORD_COUNT} random vectors..."
record_data = RECORD_COUNT.times.map do |i|
  vector_array = random_unit_vector(vector_dimension)
  [vector_array, "#{epoch}:#{i}"]
end
puts "Inserting vectors..."

ts = Time.now

index.add_batch(record_data)

dt = Time.now.-(ts).*(1e3)
puts "Added #{RECORD_COUNT} vectors in #{dt}ms (#{(dt * 1e3) / 100_000}us per vector)"
