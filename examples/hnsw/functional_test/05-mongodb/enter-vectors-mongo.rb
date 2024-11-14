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

require 'mongo'

def insert_records(collection, dimension, count, insert_one = true)
  records = []
  epoch = rand(2**63)
  documents = count.times.map do |i|
    vector = random_unit_vector(dimension)
    { vector: vector, external_id: "#{epoch}:#{i}", level: 0 }
  end
  ts = Time.now
  if insert_one
    documents.each do |doc|
      collection.insert_one(doc)
    end
  else
    collection.insert_many(documents)
  end
  dt = Time.now.-(ts).*(1e3)
  puts "Added #{count} vectors (dimension=#{dimension} in #{dt}ms (#{((dt*1e3) / count).round(3)}us per vector) #{insert_one ? 'one by one' : 'in batch'}"
end

client = Mongo::Client.new(['127.0.0.1:27017'], database: 'vectors_db', user: 'root', password: 'example', auth_source: 'admin')
#client = Mongo::Client.new('mongodb://root:example@localhost:27017/test')
db = client.database

collection = db[:vectors]
collection.drop
collection.create

# Create an index on 'external_id' (unique) and 'level' fields if they do not exist
unless collection.indexes.get('external_id_1')
  puts "Creating INDEX on 'external_id' field"
  collection.indexes.create_one({ external_id: 1 }, name: 'external_id_1', unique: true)
end

unless collection.indexes.get('level_1')
  puts "Creating INDEX on 'level' field"
  collection.indexes.create_one({ level: 1 }, name: 'level_1')
end

vector_dimension = 1024
insert_records(collection, vector_dimension, 10_000, false)
