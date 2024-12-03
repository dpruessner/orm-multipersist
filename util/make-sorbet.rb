#!/usr/bin/env ruby

require 'sorbet-runtime'
require 'orm-multipersist'
require 'pry'
require 'rbi'

module RbiGenerator
  def self.generate_rbi_for_class(klass)
    rbi = []
    rbi << "class #{klass.name}"
    
    klass.instance_methods(false).each do |method|
      method_obj = klass.instance_method(method)
      return_text = "T.untyped"
      sig = T::Utils.signature_for_method(method_obj)
      params = sig.params.map { |type, name| "#{name}: #{type}" }.join(", ")
      binding.pry
      return_text = method_obj&.return_type || 'T.untyped'
      rbi << "  sig { params(#{params}).returns(#{return_text}) }"
      rbi << "  def #{method}; end"
    end

    rbi << "end"
    rbi.join("\n")
  end
end

OrmMultipersist.eager_load
binding.pry

rbi_data = RbiGenerator.generate_rbi_for_class(OrmMultipersist::Entity)
puts "Generated RBI for OrmMultipersist::Entity:"
puts rbi_data

#File.write("sorbet/rbi/project/my_class.rbi", RbiGenerator.generate_rbi_for_class(MyClass))
