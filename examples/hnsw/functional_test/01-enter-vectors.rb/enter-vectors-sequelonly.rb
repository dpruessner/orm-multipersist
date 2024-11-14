#!/usr/bin/env ruby
require 'pry'
$LOAD_PATH.push(File.expand_path("../../lib", File.dirname(__FILE__)))

unless Dir.exist?('output')
  Dir.mkdir('output')
end

class Array
  # Return a new array with the same direction, but with a magnitude of 1
  def normalize
    mag = Math.sqrt(inject(0) { |sum, x| sum + x**2 })
    map { |x| x / mag }
  end

  def serialize
    pack('f*')
  end

  def self.random(dimension)
    Array.new(dimension) { rand(-1.0..1.0) }
  end
end

def random_unit_vector(dimension)
  Array.random(dimension).normalize
end

def insert_vectors(db, dataset, only_one: false)
  do_insert = Proc.new do |dataset|
    dataset.each do |row|
      vector_data = row[0].pack('f*')
      external_id = row[1]
      DB[:vectors].insert(vector: Sequel.blob(vector_data), external_id: external_id, level: 0)
    end
  end

  ts = Time.now
  if only_one
    db.transaction do
      do_insert.call(dataset)
    end
  else
    do_insert.call(dataset)
  end
  dt = Time.now.-(ts).*(1e3)
  puts "Added #{RECORD_COUNT} vectors in #{dt}ms (#{(dt * 1e3) / 100_000}us per vector) #{
    only_one ? 'one by one' : 'in batch' }"
end

RECORD_COUNT = 100_000

require 'sequel'
require 'sqlite3'

DB = Sequel.sqlite('output/test.sqlite3')
DB.drop_table?(:vectors)
DB.create_table?(:vectors) do
  primary_key :id
  Blob :vector, null: false
  String :external_id, null: false
  Integer :level, null: false

  index :external_id, unique: true
  index :level
end

vector_dimension = 2
epoch = Time.now.to_i
record_data = RECORD_COUNT.times.map do |i|
  vector_array = random_unit_vector(vector_dimension)
  [vector_array, "#{epoch}:#{i}"]
end

ts = Time.now

insert_vectors(DB, record_data, only_one: true)

# Add 1000 random vectors, tracking the epoch
#100_000.times do |i|
#  vector_array = random_unit_vector(vector_dimension)
#  DB[:vectors].insert(vector: Sequel.blob(vector_array.to_s), external_id: i.to_s, level: 0)
#end

