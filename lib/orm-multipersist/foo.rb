#typed: ignore

require 'pry'
require 'sorbet-runtime'
require 'active_support'
require 'active_model'

module NewCapabilities
  extend T::Sig
  extend T::Helpers

  requires_ancestor { ActiveModel::API }

  sig { params(base: Class).void }
  def self.included(base)
    base.extend(ClassMethods)
    puts "[#{name}] included"
  end

  module ClassMethods
    extend T::Sig
    extend T::Helpers
    extend T::Generic

    has_attached_class!

    requires_ancestor { Kernel }
    requires_ancestor { Module }
    requires_ancestor { T.class_of(ActiveModel::API) }

    def print_hello
      puts "Hello from #{name}"
    end

    sig { returns(T.attached_class) }
    def factory
      instance = new({})
    end
  end

  mixes_in_class_methods(ClassMethods)
end

module Foolio
  include NewCapabilities

  print_hello
end
