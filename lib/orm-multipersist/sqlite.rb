require_relative "version"
require_relative "entity"
require_relative "backend"

require "sqlite3"
require "sequel"

module OrmMultipersist
  class SqliteBackend
    include OrmMultipersist::Backend

    def initialize(db_path)
      @db_path = db_path
      @db = Sequel.sqlite3(@db_path)
    end
    attr_reader :db_path, :db

    ## Creates a record
    def create_record(record, _orm_klass)
      dataset = record.class.client.db.dataset.from(record.class.table_name)
      values = {}
      record.changed.each { |a| values[a.to_sym] = record.send(a.to_sym) }
      rv = dataset.insert(values)
      return unless record.class.primary_key
      record.set_primary_key_attribute(rv)
      nil
    end

    def update_record(record, _orm_klass)
      dataset = record.class.client.db.dataset.from(record.class.table_name)
      values = {}
      record.changed.each { |a| values[a.to_sym] = record.send(a.to_sym) }
      if record.class.has_primary_key?
        pkey = record.class.primary_key
        dataset = dataset.where_single_value(pkey => record.send(pkey))
      else
        where_values = values.dup
        record.changes.each { |k, values| where_values[k] = values[0] }
        dataset = dataset.where(where_values)
      end
      rv = dataset.update(values)
    end

    def destroy_record(record, orm_klass)
      raise NotImplementedError, "destroy_record must be implemented in #{self.class}"
    end

    def client_klass_detail
      "sqlite3:#{@db_path}"
    end
  end
end
