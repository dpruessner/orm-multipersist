# typed: true 
require 'pry'
require 'sorbet-runtime'
require 'orm-multipersist'
require 'rbi'

module RbiSerializer
  def self.serialize_signature_to_rbi(signature, method_name)
##    # Extract parameters and return type
##    params = signature.parameters.map do |param_name, type|
##      "#{param_name}: #{type}"
##    end.join(", ")
##
##    return_type = signature.return_type
##
##    # Check if the method is void or has a return type
##    rbi_return_type = return_type.is_a?(T::Private::Types::Void) ? "void" : return_type.to_s
##    # Construct the RBI method definition
##    [
##      "  sig { params(#{params}).returns(#{rbi_return_type}) }",
##      "  def #{method_name}; end"
##    ].join("\n")
"{---}"
  end

  # @param signature [T::Private::Methods::Signature]
  # @param method_name [String]
  # @param tree_node [RBI::Class|RBI::Module|RBI::Namespace|RBI::Tree]
  # @return [RBI::Tree]
  def self.serialize_signature_to_tree(signature, method_name, tree_node, method_obj)
    # Extract parameters and return type
    tree_node << RBI::Method.new(method_name.to_s) do |method|
      (signature&.parameters || method_obj.parameters).each do |reqtype, name|
        case reqtype
        when :req
          method.add_param(name.to_s)
        when :opt
          method.add_opt_param(name.to_s, "T.unsafe(nil)")
        when :block
          method.add_block_param(name.to_s)
        when :rest
          method.add_rest_param(name.to_s)
        when :keyrest
          method.add_kw_rest_param(name.to_s)
        when :key
          method.add_kw_param(name.to_s)
        else
          raise RuntimeError, "Do not know what to do with method parameter type #{reqtype} (#{method_name}) in #{(signature || method_obj).owner} (has signature: #{!signature.nil?})"
          #raise RuntimeError, "Do not know what to do with method parameter type #{reqtype}"
        end
      end

      if signature.nil?
        method.comments << RBI::Comment.new("no signature found")
        next # Break out of the block
      end


      return_type = signature.return_type.is_a?(T::Private::Types::Void) ? "void" : signature.return_type.to_s

      sig_opts = { params: [], return_type: return_type }
      sig_opts[:params] = signature.arg_types.map do |param_name, type, raw_type|
        RBI::SigParam.new(param_name.to_s, type.to_s)
      end

      if signature.block_name
        block_param = RBI::SigParam.new(signature.block_name.to_s, signature.block_type.to_s)
        sig_opts[:params] << block_param
      end

      nullproc = Proc.new {|*_args| nil }

      # If defined a sig{ ... } block with arg types
      unless signature.nil?
      #unless signature.arg_types.empty? and signature.return_type.nil? and signature.block_type
        method.add_sig(**sig_opts, &nullproc)
      end

    end
  end
end

# rubocop:disable all

module MyClassMixin
end

module MyInstanceMixin
end

class MyParentClass

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

  def initialize
  end

  sig { params(x: Integer, y: T.nilable(Integer)).returns(Integer) }
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

  def my_untyped_function
  end

end
#rubocop:enable all

# Refactor TODO:
#   1. Track dependencies within the namespace so that we can continue generating the tree
#      needed for sorbet (especially for relocating a namespace)
#
class DpRbiGenerator
  extend T::Sig

  DEFAULT_DEPENDENCIES = {
    "Kernel" => true,
    "Object" => true,
    "BasicObject" => true
  }.freeze

  sig { returns(RBI::Node) }
  attr_reader :tree_root

  sig { returns(RBI::Node) }
  attr_reader :tree

  sig do
    params(
      redirect_to: T.nilable(String),
      restrict_dependency_namespace: T.nilable(String)
    ).void
  end
  def initialize(redirect_to: nil, restrict_dependency_namespace: nil)
    @tree = RBI::Tree.new
    @redirect_namespace = redirect_to
    @output_namespaces = T.let([], T::Array[String])

    # Name dependencies we need to output (track what we've defined, what is left to define)
    @dependencies = T.let({}.merge(DEFAULT_DEPENDENCIES), T::Hash[String, T::Boolean])

    # Namespace to restrict adding (tracking) dependencies
    @restrict_dependency_namespace = restrict_dependency_namespace

    if @redirect_namespace
      create_path_for_namespace(@tree, @redirect_namespace)
      @redirect_node = RBI::Module.new(@redirect_namespace)
      @tree << @redirect_node
      @tree_root = @tree
      @tree = @redirect_node
    end

  end

  # Return a list of names that have not yet been defined, optionally 
  # limiting to a namespace.
  #
  # @param namespace [String|nil]
  # @return [Array[String]]
  #
  sig { params(namespace: T.nilable(String)).returns(T::Array[String]) }
  def undefined_dependencies(namespace=nil)
    if namespace.nil?
      @dependencies.select { |_name, defined| !defined }.keys
    else
      @dependencies.select { |name, defined| !defined && name.start_with?(namespace) }.keys
    end
  end

  # Resolve all dependencies: this will loop in adding the classes/modules needed until all
  # dependencies are resolved.
  #
  # @return [Array[String]] list of resolved dependencies from this process
  #
  sig { params(namespace: T.nilable(String)).returns(T::Array[String]) }
  def resolve_dependencies(namespace = nil)

    resolved_deps = T.let([], T::Array[String])
    while undefined_dependencies(namespace).any?
      undefined_dependencies.each do |name|
        obj = runtime_lookup_const(name)
        if obj
          if obj.is_a?(Class)
            make_rbi_klass_tree(obj)
          else 
            T.assert_type!(obj, Module) { |x| "Expected #{x} to be a Module since it is not a Class (coming from runtime_lookup_const)" }
            make_rbi_module_tree(obj)
          end
          # create_path_for_namespace(@tree, name)
          @dependencies[name] = true
          resolved_deps << name
        end
      end
    end
    resolved_deps
  end

  # Mark that a dependency is needed.
  #
  # If the dependency is already defined, do nothing.
  #
  # Returns if the dependency is already defined
  #
  sig { params(name: String).returns(T::Boolean) }
  def add_dependency(name)
    raise RuntimeError, "Cannot add an empty-name dependency" if name.empty?

    # skip if we are restricting dependencies to a namespace (act like it's already defined)
    return true if @restrict_dependency_namespace && !name.start_with?(@restrict_dependency_namespace)

    @dependencies[name] = false unless @dependencies.key?(name)
    return @dependencies[name] == true
  end

  # Mark that a dependency is complete.
  sig { params(name: String).void }
  def complete_dependency(name)
    @dependencies[name] = true
  end


  sig { params(name: String).returns(T.nilable(T.any(Class, Module))) }
  def runtime_lookup_const(name)
    names = name.split('::')
    names.reduce(Kernel) do |mod, const_name|
      mod.const_get(const_name)
    end
  end

  # Creaet a path for a namespace in the tree.  This looks like
  # declaring the series of names neeeded to create the namespace
  # path (modules and classes) in the tree.
  #
  # @param tree [RBI::Tree]
  # @param klass [Class|Module]
  #
  sig { params(tree: RBI::Tree, klass_name: String).void }
  def create_path_for_namespace(tree, klass_name)
    return if @output_namespaces.include?(klass_name)

    # walk the name until we have a name that has not been output
    name_elements = klass_name.split('::')
    current_name = name_elements.shift
    if current_name.nil?
      return
    end

    loop do
      break if current_name == klass_name

      unless @output_namespaces.include?(current_name)
        # Define the current_name
        obj = runtime_lookup_const(current_name)
        raise "Could not find constant #{current_name}" unless obj
        tree << if obj.is_a?(Class)
                  RBI::Class.new(current_name)
                else
                  RBI::Module.new(current_name)
                end
        @output_namespaces << current_name
      end

      break if name_elements.empty?
      current_name = "#{current_name}::#{name_elements.shift}"
    end
    true
  end

  # Search upward toward root to find a path that includes 'sorbet/config'
  sig { returns(T.nilable(String)) }
  def find_sorbet_root
    @find_sorbet_root ||=
      begin
        path = Dir.pwd
        while path != '/'
          return path if File.exist?(File.join(path, 'sorbet', 'config'))
          path = File.dirname(path)
        end
        nil
      end
  end

  def sorbet_project_class_path(klass)
    sorbet_root = find_sorbet_root
    raise "Could not find sorbet root" unless sorbet_root
    sorbet_path = File.join(sorbet_root, 'sorbet')
    class_path = klass.name.split('::').map(&:downcase).join('/')
    File.join(sorbet_path, 'rbi', 'project', "#{class_path}.rbi")
  end

  def write_rbi(klass, tree)
    rbi_path = sorbet_project_class_path(klass)
    # Check that the directory exists with FileUtils.mkdir_p
    dirname = File.dirname(rbi_path)
    FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
    # Write the file
    File.write(rbi_path, tree.string)
  end

  sig { params(klass: T.any(Class, Module), exclude_list: T::Array[T.any(Class, Module)]).void }
  def each_unique_ancestry(klass, exclude_list)
    ancestors = klass.ancestors
    ancestors -= exclude_list

    while !ancestors.empty?
      current_ancestor = T.cast(ancestors.shift, Module)
      yield current_ancestor
      # Remove this current ancestor's ancestors from the list
      ancestors -= current_ancestor.ancestors
    end
  end

  def add_class_methods_to_tree(klass, tree)
    klass_methods = klass.methods(false)
    return if klass_methods.empty?
    tree << RBI::SingletonClass.new do |tree|
      tree.comments << RBI::Comment.new("Class methods")
      klass.methods(false).each do |method_name|
        method_obj = klass.singleton_method(method_name)
        signature = T::Utils.signature_for_method(method_obj)
        RbiSerializer.serialize_signature_to_tree(signature, method_name, tree, method_obj)
      end
    end
  end

  sig do 
    params(
      obj: T.any(Class, Module),
      exclude_list: T::Array[T.any(Class, Module)],
      blk: T.proc.params(x: T.any(Class, Module)).void
    )
      .void 
  end
  def each_unique_ancestor(obj, exclude_list, &blk)
    ancestors = obj.ancestors
    ancestors_seen = T.let([obj] + exclude_list, T::Array[T.any(Class, Module)])
    ancestors.each do |ancestor|
      next if ancestors_seen.include?(ancestor)
      ancestors_seen << ancestor
      yield ancestor
      ancestors_seen += ancestor.ancestors
      ancestors_seen.uniq!
    end
  end

  sig { params(mod: Module).void }
  def make_rbi_module_tree(mod)
    tree = @tree
    mod_name = mod.name
    raise RuntimeError, "ended up in make_rbi_mnodule_tree for a module with no name" if mod_name.nil?
    create_path_for_namespace(tree, mod_name)

    add_dependency(mod_name)
    complete_dependency(mod_name)

    tree << RBI::Module.new(mod_name) do |tmod|
      @output_namespaces << mod_name

      # Get the ancestors
      ancestors = mod.ancestors
      ancestors -= [mod]

      each_unique_ancestor(mod, [mod, ::Module, ::Object, ::BasicObject]) do |ancestor|
        #next if ancestor == Module
        ancestor_name = ancestor.name.to_s
        next if ancestor_name.empty? || ancestor_name =~ /T::/
        tmod << RBI::Include.new(ancestor_name)
        if add_dependency(ancestor_name) != true
          puts ">  Adding dependency for #{ancestor_name} (Module-level for #{mod_name})"
        end
      end

      # Add in singleton class methods
      singleton_klass = mod.singleton_class
      if singleton_klass
        each_unique_ancestor(singleton_klass, [singleton_klass, ::Module, ::Object, ::BasicObject]) do |ancestor|
          ancestor_name = ancestor.name.to_s
          next if ancestor_name.empty? || ancestor_name =~ /T::/
          #next if ancestor == Object || ancestor == Module
          tmod << RBI::Extend.new(ancestor_name)
          if add_dependency(ancestor_name) != true
            puts ">  Adding dependency for #{ancestor_name} (Singleton-level for #{mod_name})"
          end
        end
      end
      #
      # Make methods
      mod.instance_methods(false).each do |method_name|
        method_obj = mod.instance_method(method_name)
        signature = T::Utils.signature_for_method(method_obj)
        RbiSerializer.serialize_signature_to_tree(signature, method_name, tmod, method_obj)
      end

      tmod << RBI::Method.new("__rbi_loaded") do |method|
        method.add_sig(return_type: "T::Boolean"){ |sig| }
        method.comments << RBI::Comment.new("This is a marker method for srb to indicate the rbi is loaded from generated code")
      end

      add_class_methods_to_tree(singleton_klass, tmod) if singleton_klass
    end
  end

  sig { params(klass: Class).void }
  def make_rbi_klass_tree(klass)
    tree = @tree
    klass_name = klass.name
    if klass_name.nil?
      raise "Could not find name for class #{klass}"
    end

    create_path_for_namespace(tree, klass_name)
    add_dependency(klass_name)
    complete_dependency(klass_name)


    tree << RBI::Class.new(klass_name) do |tklass|
      @output_namespaces << klass_name

      #tklass.comments << RBI::Comment.new("## This is a generated class definition; do not edit ######")

      # Check ancestry
      superclass = klass.superclass
      unless superclass.nil?
        if superclass.name.nil?
          raise "Could not find name for superclass of #{klass} -- May need to extend DpLocalRbiGenerator to handle this case"
        end
        superclass_name = T.cast(superclass.name, String)
        add_dependency(superclass_name)
        tklass.comments << RBI::Comment.new("##-- Superclass: #{superclass_name}")
        tklass.superclass_name = superclass_name unless superclass_name == "Object"
      else
        tklass.comments << RBI::Comment.new("##-- No superclass defined")
      end

      # Get ancestors, but remove overlapping modules
      exclude_parents = T.let([klass], T::Array[Class])
      klass.superclass&.tap do |sc| 
        exclude_parents << sc
        exclude_parents << sc.ancestors
      end
      exclude_parents.flatten!
      unique_parents = klass.ancestors - exclude_parents
      unique_parents.reverse.each do |current_ancestor|
        if current_ancestor.is_a?(Module)
          if add_dependency(current_ancestor.name.to_s) != true
            puts ">  Adding dependency for #{current_ancestor.name}"
          end
          tklass << RBI::Include.new(current_ancestor.name.to_s)
        end
      end

      # ClassMethods (singleton)
      exclude_parents = T.let([klass.singleton_class], T::Array[Class])
      klass.superclass&.tap do |sc|
        sc = T.cast(sc, Class)
        exclude_parents << sc.singleton_class
        exclude_parents = exclude_parents + T.cast(sc.singleton_class.ancestors, T::Array[Class])
      end
      exclude_parents.flatten!
      klass_parents = klass.singleton_class.ancestors - exclude_parents
      # Add in singleton class methods
      klass_parents.reverse.each do |current_ancestor|
        next if current_ancestor.singleton_class?
        next if (current_ancestor.name || "") =~ /T::/
        if current_ancestor.is_a?(Module)
          if add_dependency(current_ancestor.name.to_s) != true
            puts ">  Adding dependency for #{current_ancestor.name}"
          end

          tklass << RBI::Extend.new(current_ancestor.name.to_s)
        end
      end

      # Make methods
      klass.instance_methods(false).each do |method_name|
        method_obj = klass.instance_method(method_name)
        signature = T::Utils.signature_for_method(method_obj)
        RbiSerializer.serialize_signature_to_tree(signature, method_name, tklass, method_obj)
      end

      tklass << RBI::Method.new("__rbi_loaded") do |method|
        method.add_sig(return_type: "T::Boolean"){ |sig| }
        method.comments << RBI::Comment.new("This is a marker method for srb to indicate the rbi is loaded from generated code")
      end

      add_class_methods_to_tree(klass, tklass)
    end

    #puts "Generated RBI for #{klass}:"
    #puts tree.string
    #tree
  end

  sig { params(output: T.any(String, IO)).void }
  def write_to(output)
    fh = nil
    if output.is_a?(String)
      fh = File.open(output, 'w')
    end
    (fh || output).tap do |io|
      io.write("# typed: true\n\n#{tree.string}")
      if undefined_dependencies.any?
        io.write("\n# Missing dependencies:\n")
        undefined_dependencies.each do |dep|
          io.write("#   #{dep}\n")
        end
      end
    end
    fh&.close # only close the file handle if we opened it
  end
end

generator = DpRbiGenerator.new(
  redirect_to: "Foolio",
  restrict_dependency_namespace: "OrmMultipersist"
)

generator.make_rbi_module_tree(OrmMultipersist::Entity)
generator.make_rbi_module_tree(OrmMultipersist::Backend)
puts "Resolving dependencies..."
generator.resolve_dependencies("OrmMultipersist").each do |dep|
  puts "    resolved: #{dep}"
end

generator.write_to(generator.sorbet_project_class_path(OrmMultipersist))
#generator.write_to(STDOUT)


##File.open(generator.sorbet_project_class_path(OrmMultipersist), 'w') do |f|
##  f.puts "# typed: true"
##  f.puts
##  f.puts generator.tree_root.string
##end

if ENV['false']
  f = Example.new
  f.add(1)

  f = Foolio::OrmMultipersist::RbiExample::Example.new
  f.__rbi_loaded
end
binding.pry if ARGV.first == "pry"

