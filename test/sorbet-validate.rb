# typed: ignore
#
#
require 'sorbet-runtime'
require 'active_model'
require 'pry'

#module GenericClassMethodInterface
#  extend T::Sig
#  extend T::Helpers
#  extend T::Generic
#
#  abstract!
#  has_attached_class!
#  
#  sig { abstract.returns(T.attached_class) }
#  def new; end
#
#  sig { abstract.returns(String) }
#  def name; end
#
#  sig { abstract.returns(T.attached_class) }
#  def allocate; end
#
#end
#
#module GenericInstanceMethodInterface
#  extend T::Sig
#  extend T::Helpers
#  extend T::Generic
#
#  interface!
#  requires_ancestor{ GenericClassMethodInterface }
#  
#  sig { abstract.void }
#  def initialize; end
#
#  sig { abstract.returns(Class) }
#  def class; end
#end



module M
  extend T::Sig
  extend T::Helpers
  extend T::Generic

  requires_ancestor { Kernel }

  sig { params(base: Class).void }
  def self.included(base)
    Kernel.puts "#{self.name} included in #{base.name}"
    base.extend(ClassMethods)
  end

  module ClassMethods
    extend T::Sig
    extend T::Helpers
    requires_ancestor { T.class_of(Object) }

    sig { params(value: Numeric).void }
    def set_M_class_attribute(value)
      @M_attribute = value
    end

    sig { returns(Numeric) }
    def get_M_class_attribute
      @M_attribute
    end

    def new(value=1)
      Kernel.puts "#{self.name} #new -- value=#{value}"
      instance = new
      instance.instance_variable_set(:@value, value)
      instance
    end

    def m_factory_method
      Kernel.puts "#{self.name}::m_factory_method"
      self.new
    end
  end # class methods

  sig { void }
  def m_method
    puts "m_method"
    nil
  end

  def initialize(value=2)
    Kernel.puts "#{self.class.name} #initialize -- value=#{value}"
  end

  mixes_in_class_methods(ClassMethods)
end

class F
  include M
end

F.m_factory_method

module I
  extend T::Sig

  sig { params(base: Class).void }
  def self.included(base)
    base.include(M)
    base.include(E)
  end
end
  

module E
  extend T::Sig
  extend T::Helpers
  extend T::Generic

  requires_ancestor { M }

  sig { params(base: Class).void }
  def self.included(base)
    Kernel.puts "#{self.name} included in #{base.name}"
    base.include(M)
    base.extend(ClassMethods)
  end

  def call_m_factory
    self.class.m_factory_method
  end
  
  module ClassMethods
    extend T::Sig
    extend T::Helpers
    extend T::Generic
  end

  sig { returns(T.self_type) }
  def get_another
    Kernel.puts "#{self.class.name} #get_another"
    self.class.m_factory_method
  end

  def e_method
    puts "e_method"
    self.m_method
  end

  mixes_in_class_methods(ClassMethods)
end


class MyEntity
  extend T::Sig
  extend T::Helpers
  include I

  attr_accessor :value
end

MyEntity.new.e_method
binding.pry


module Green
  extend T::Sig
  extend T::Helpers

  module ClassMethods
    extend T::Sig
    extend T::Helpers

    sig { returns(Numeric) }
    def g_class_method
      Kernel::puts "g_class_method"
      Time.now.to_i
    end
    def self.extended(base)
      puts "#{self.name} extended in #{base.name}"
    end
  end

  mixes_in_class_methods(ClassMethods)
end

module HOuter
  extend T::Sig
  extend T::Helpers

  def self.included(base)
    base.include(Green)
    base.include(HInner)
    base.extend(ClassMethods)
  end
  module ClassMethods
  extend T::Sig
  extend T::Helpers
  end
end

module HInner
  extend T::Sig
  extend T::Helpers

  module ClassMethods
    extend T::Sig
    extend T::Helpers
    sig { void }
    def h_class_method
      Kernel::puts "h_class_method"
    end
  end
  mixes_in_class_methods(ClassMethods)

  sig { void }
  def h_instance_method
    puts "calling g_class_method on self.class"
    T.cast(self.class, T.class_of(Green)).g_class_method
  end

  def foo
    self.class.h_instance_method
  end

end


class MyKlass
  include HOuter
end


MyKlass.h_class_method

binding.pry




module MyGeneric1
  extend T::Sig
  extend T::Helpers

  requires_ancestor { Kernel }

  module ClassMethods
    extend T::Sig
    sig { returns(Numeric) }
    def generic_class_method
      Time.now.to_i
    end
  end

  sig { params(base: T.class_of(Object)).void }
  def self.included(base)
    base.extend(ClassMethods)
  end

  def something
    self.class.generic_class_method
  end
end
####  # typed: true
####  require 'sorbet-runtime'
####  
####  module MyModule
####    extend T::Sig
####    extend T::Helpers
####    requires_ancestor { Kernel }
####  
####    module ClassMethods
####      extend T::Sig
####  
####      sig { params(value: Integer).returns(Integer) }
####      def double(value)
####        value * 2
####      end
####    end
####  
####    sig { params(base: T.class_of(Object)).void }
####    def self.included(base)
####      base.extend(ClassMethods)
####    end
####  
####    sig { params(value: Integer).returns(Integer) }
####    def use_class_method(value)
####      # Call the class method on the including class
####      self.class.double(value)
####    end
####  end
####  
####  class MyClass
####    extend T::Sig
####    include MyModule
####  
####    sig { void }
####    def demonstrate
####      puts use_class_method(10) # Calls the `double` class method from ClassMethods
####    end
####  end
####  
####  # Usage
####  my_instance = MyClass.new
####  my_instance.demonstrate


# typed: true
require 'sorbet-runtime'

module MyModule
  extend T::Sig
  extend T::Helpers
  requires_ancestor { Kernel }

  module ClassMethods
    extend T::Sig
    extend T::Helpers

    requires_ancestor { T.class_of(Object) }

    sig { params(value: Integer).returns(String) }
    def double_with_class_name(value)
      "#{name}: #{value * 2}"
    end
  end

  sig { params(base: T.class_of(Object)).void }
  def self.included(base)
    base.extend(ClassMethods)
  end

  sig { params(value: Integer).returns(String) }
  def use_class_method(value)
    # Call the class method on the including class
    self.class.double_with_class_name(value)
  end
end

class MyClass
  extend T::Sig
  include MyModule

  sig { void }
  def demonstrate
    puts use_class_method(10) # Calls the `double_with_class_name` class method from ClassMethods
  end
end

# Usage
my_instance = MyClass.new
my_instance.demonstrate
