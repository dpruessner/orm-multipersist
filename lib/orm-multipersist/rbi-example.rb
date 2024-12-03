# typed: true

require 'sorbet-runtime'

# rubocop:disable all
module OrmMultipersist::RbiExample
  module MyClassMixin
  end

  module MyInstanceMixin
  end

  module ParentclassClassMethods
    def parent_class_method2
    end
  end

  class MyParentClass
    extend T::Sig
    extend ParentclassClassMethods

    sig { returns(T::Boolean) }
    def self.parent_class_method
      true
    end
  end


  #
  # Example usage
  class Example < MyParentClass
    extend T::Sig
    extend MyClassMixin
    include MyInstanceMixin

    #
    # Method that is yielded an array of Integers and should return a Boolean
    #
    # @yieldparam list [Array[Integer]] array of integers
    # @yieldreturn [Boolean]
    #
    sig { params(block: T.proc.params(list: T::Array[Integer]).returns(T::Boolean)).returns(T::Boolean) }
    def my_function_with_block(&block)
      block.call([1, 2, 3]) == true
    end

    sig { params(x: Integer, y: T.nilable(Integer)).returns(Integer) }
    # Add two numbers
    def add(x, y = 2)
      x + (y.nil? ? 0 : y)
    end

    sig { params(x: Integer, y: T.nilable(Integer)).returns(Integer) }
    def multiply(x, y = 1)
      1
    end

    sig { void }
    def no_op; end

    sig { returns(T::Boolean) }
    def self.my_class_method
      true
    end

  end
end
#rubocop:enable all
