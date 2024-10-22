require_relative "version"
require_relative "entity"
require_relative "backend"
require_relative "recordset"
require 'awesome_print'


require "sqlite3"
require "sequel"

module OrmMultipersist
  class SqliteBackend
    ## Type translation to Sequel/Sqlite3 types from ActiveModel types
    TYPE_TRANSLATION = {
      ActiveModel::Type::Integer => :integer,
      ActiveModel::Type::String => :string,
      ActiveModel::Type::Binary => :blob,
      ActiveModel::Type::Float => :real,
      ActiveModel::Type::Boolean => :integer
    }.freeze

    include OrmMultipersist::Backend

    def initialize(db_path)
      @db_path = db_path
      @db = Sequel.sqlite(@db_path)
    end
    attr_reader :db_path, :db

    ## Creates a record
    def create_record(record, _orm_klass)
      dataset = record.class.client.db.dataset.from(record.class.table_name)
      values = {}
      record.changed.each { |a| values[a.to_sym] = record.send(a.to_sym) }
      rv = dataset.insert(values)
      return unless record.class.has_primary_key?
      record.set_primary_key_attribute(rv)
      nil
    end

    def update_record(record, _orm_klass)
      dataset = record.class.client.db.dataset.from(record.class.table_name)
      values = {}
      record.changed.each { |a| values[a.to_sym] = record.send(a) }
      if record.class.has_primary_key?
        pkey = record.class.get_primary_key
        dataset = dataset.where(pkey => record.send(pkey))
      else
        where_values = record.attribute_names.each.map do |att_name|
          [att_name.to_sym, record.send(att_name)]
        end
        record.changes.each do |k, values|
          where_values << [k.to_sym, values[0]]
          # puts "     setting #{k.inspect}=#{values[0].inspect}"
        end
        # puts "... where_values=#{where_values.inspect} after adding in the original values"
        where_values = Hash[where_values]
        dataset = dataset.where(where_values)
      end

      dataset.update(values)
      # puts "... rv=#{rv.inspect}"
    end

    ## Ensure that a table exists in the SQLite database, using Sequel to create it
    def ensure_table!(entity_klass)
      attributes = entity_klass.attribute_types
      db.create_table?(entity_klass.table_name) do
        primary_key_name = nil
        primary_key_name = entity_klass.get_primary_key.to_s if entity_klass.has_primary_key?
        attributes.each do |name, attr|
          # puts "Adding column #{name} of type #{attr.class} (#{attr})"
          column_type = TYPE_TRANSLATION[attr.class]
          raise ArgumentError, "Unsupported type #{attr.class} for column #{name}" if column_type.nil?
          options = {}
          options[:primary_key] = true if name == primary_key_name
          column name, column_type, options
        end
      end
    end

    def lookup_by_primary_key(value, entity_klass)
      dataset = entity_klass.client.db.dataset.from(entity_klass.table_name)
      pkey = entity_klass.get_primary_key
      dataset = dataset.where(pkey => value).limit(1)
      data = dataset.to_a.first
      record = nil
      if data
        record = entity_klass.new(data)
        record.set_persisted
        record.changes_applied
      end
      record
    end

    def destroy_record(record, orm_klass)
      raise NotImplementedError, "destroy_record must be implemented in #{self.class}"
    end

    def client_klass_detail
      "sqlite3:#{@db_path}"
    end

    # Recordset class for SQLite3 queries
    #
    # Limits applications of operations (lookup, delete, update) to subsets of the records within a table.
    #
    class SqliteRecordset < OrmMultipersist::Recordset
      # Access the underlying dataset (Sequel::SQL::Dataset) for this recordset; should only be used for testing
      attr_accessor :dataset

      def initialize(backend, entity_klass)
        super
        @dataset = @backend.db.dataset.from(@entity_klass.table_name)
      end

      # Changes every record matching the *recordset*.
      #
      # @return [Integer] the number of records updated
      #
      def update(values)
        update_values = values.each { |k, v| [k.to_sym, v] }
        @dataset.update(Hash[update_values])
      end

      # Deletes from the persistence every record matching the *recordset*
      #
      # @return [Integer] the number of records deleted
      #
      def delete!
        @dataset.delete
      end

      # Limit the recordset to `count` records.  Will override if used multiple times.
      #
      # @return [SqliteRecordset] self
      #
      def limit(count)
        @dataset = @dataset.limit(count)
        self
      end

      # Offset the recordset by `count` records.  Will override if used multiple times.
      #
      # @return [SqliteRecordset] self
      #
      def offset(count)
        @dataset = @dataset.offset(count)
        self
      end

      # Remove any ordering specification
      #
      # @return [SqliteRecordset] self
      #
      def order_by_none
        @order_by = []
        @dataset = @dataset.order_by(nil)
        self
      end

      # Iterate over all the records
      #
      # @yield [record] each record
      # @yieldparam [Hash] record columns
      #
      # @return [SqliteRecordset] self
      def each(&block)
        return enum_for(:each) unless block_given?
        @dataset.each do |record|
          instance = @entity_klass.new(record)
          instance.set_persisted
          block.call(instance)
        end
      end

      # Get all records as an array
      # @return [Array<Entity>] array of records
      def all
        @dataset.all.map do |record|
          instance = @entity_klass.new(record)
          instance.set_persisted
          instance
        end
      end

      # Get the first record
      def first
        record = @dataset.first
        unless record.nil?
          instance = @entity_klass.new(record)
          instance.set_persisted
          return instance
        end
        nil
      end

      # Get the number of records in the recordset
      # @return [Integer] number of records
      def count
        @dataset.count
      end

      # Order the recordset by a column
      #
      # @overload
      #   order_by(fieldname, ...)
      #   @param [String, Symbol] fieldname to sort ascending
      #
      # @overload
      #   order_by(fielname: direction, ...)
      #   @param [Hash] fieldname: direction to sort
      #
      #
      # @return [SqliteRecordset] self
      #
      def order_by(order = {}, *args, **kwarg)
        # Case: only one attribute (default is ascending)
        order = { order.to_sym => 1 } if order.is_a?(String) || order.is_a?(Symbol)

        # Case: multiple attributes as args
        args.each { |v| order[v.to_sym] = 1 }

        # Case: multiple attributes with directions (as kwargs)
        order = order.merge(kwarg)

        #puts "#{self.class}##{__method__}: ENTER (@order_by=#{@order_by.inspect}, order=#{order.inspect})"

        # preserve original order_by ordering, but cause new values to delete and move the ordering to the back-of-the-line
        order_names = []
        order_values = {}
        @order_by.each do |name, direction|
          #puts "@order_by.each(name=#{name}, direction=#{direction})"
          order_names << name
          order_values[name] = direction
        end
        #puts "#{self.class}##{__method__}: order_names=#{order_names.inspect}, order_values=#{order_values.inspect}"

        order.each do |name, direction|
          name = name.to_sym
          order_names.delete(name) if order_values[name]
          order_values[name] = direction
          order_names << name
        end

        # Update the order_by
        @order_by = order_names.map { |name| [name, order_values[name]] }

        order = @order_by.map do |name, direction|
          if direction == 1
            Sequel.asc(name.to_sym)
          elsif direction == -1
            Sequel.desc(name.to_sym)
          else
            raise ArgumentError, "Invalid direction #{direction.inspect}"
          end
        end
        @dataset = @dataset.order_by(*order)
        self
      end

      # Limit records by conditions that all must be met
      #
      # Conditions specified as `field => value` or `field => { operator => operand }`.
      # *See the MongoDB query document specificication*.
      #
      # Operators currently implemented:
      # * `$lt` (less than)
      # * `$gt` (greater than)
      # * `$lte` (less than or equal)
      # * `$gte` (greater than or equal)
      # * `$ne` (not equal)
      # * `$in` (value in array)
      # * `$nin` (value not in array)
      #
      #
      # @return [SqliteRecordset] self
      #
      def and(conds = {}, **named)
        conds = conds.merge(named) unless named.empty?
        conds = mongo_to_sequel_conditions(conds)

        @dataset = @dataset.where(conds)
        self
      end

      def or(conds = {}, **named)
        conds = conds.merge(named) unless named.empty?
        conds = mongo_to_sequel_conditions(conds)

        @dataset = @dataset.or(conds)
        self
      end

      private

      # Map a condition from the MongoDB format (`{"fieldname" => { "operator" => value}}`) to a Sequel condition
      #
      # Sequel conditions are an array of conditions that can be  Sequel::SQL::PlaceholderLiteralString
      #
      # @param [Hash] conditions the MongoDB conditions
      # @return [Array<Sequel::SQL::PlaceholderLiteralString>] the Sequel conditions
      #
      #
      def mongo_to_sequel_conditions(conditions, join_style = :and)
        conditions = conditions.map do |key, value|
          if key == "$or"
            value.map { |v| mongo_to_sequel_conditions(v) }.inject(:|)
          elsif value.is_a?(Hash)
            process_hash_condition(key, value)
          else
            # TODO: Maybe handle an array type here (for $in, $nin short-cut)
            Sequel.lit("\"#{key}\" = ?", value)
          end
        end

        if join_style == :and
          conditions.inject(:&)
        elsif join_style == :or
          conditions.inject(:|)
        else
          raise ArgumentError, "Unsupported join_style: #{join_style.inspect}"
        end
      end

      # Process a hash condition
      # 
      # @param [String] key the field name
      # @param [Hash] value the value hash
      #
      # @example Basic usaage
      #   process_hash_condition("fieldname", { "$lt" => 30 })
      #   # => Sequel::SQL::PlaceholderLiteralString
      #
      #   process_hash_condition("fieldname", { "$lt" => 30, "$gt" => 10 })  # fieldname between 10 and 30 (exclusive)
      #   # => Sequel::SQL::PlaceholderLiteralString
      #
      #   process_hash_condition("fieldname", { '$lt' => 30, '$or' => [ '$gt' => 10, '$eq' => 5 ] }) # fieldname between 10 and 30 (exclusive) or equal to 5
      #
      def process_hash_condition(key, value, join_style = :and)
        ary = value.map do |op, val|
          case op
          when "$eq"    then Sequel.lit("\"#{key}\" = ?", val)
          when "$ne"    then Sequel.lit("\"#{key}\" != ?", val)
          when "$lt"    then Sequel.lit("\"#{key}\" < ?", val)
          when "$lte"   then Sequel.lit("\"#{key}\" <= ?", val)
          when "$gt"    then Sequel.lit("\"#{key}\" > ?", val)
          when "$gte"   then Sequel.lit("\"#{key}\" >= ?", val)
          when "$in"    then Sequel.lit("\"#{key}\" IN ?", val)
          when "$nin"   then Sequel.lit("\"#{key}\" NOT IN ?", val)
          when "$regex" then Sequel.lit("\"#{key}\" REGEXP ?", val)
          else
            raise "Unsupported operator: #{op.inspect} for key #{key.inspect} with value #{val.inspect}"
          end
        end

        if join_style == :and
          ary.inject(:&)
        elsif join_style == :or
          ary.inject(:|)
        else
          raise ArgumentError, "Unsupported join_style: #{join_style.inspect}"
        end
      end
    end
  end
end
