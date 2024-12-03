# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'active_model'

## Main module
#
# OrmMultipersist is a gem that allows you to use multiple ORMs in the same project.
# This allows app developers to test complex pipelines or object interactions locally (via persistence like SQLite)
# and then deploy to a cloud environment (like AWS) with a different ORM (like DynamoDB or RDS).
#
# OrmMultipersist adds some translation for some types that are used in vector databases and LLM systems, as this is the
# original purpose of this project.  Additional types and persistences may be added on request.
#
module OrmMultipersist

  # Eager load all the classes in the gem
  # Returns constants that were loaded
  #
  # @return [Array] of constants that were loaded
  #
  def self.eager_load
    konstants_orig = OrmMultipersist.constants
    Dir.glob(File.join(File.dirname(__FILE__), 'orm-multipersist', '**', '*.rb')).each do |file|
      require file
    end
    OrmMultipersist.constants.-(konstants_orig).sort
  end
end

require 'active_model/attributes'

require 'orm-multipersist/version'
require 'orm-multipersist/entity'
require 'orm-multipersist/backend'
require 'orm-multipersist/recordset'
require 'orm-multipersist/rbi-example'

