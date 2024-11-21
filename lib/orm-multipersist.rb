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
end

require_relative 'orm-multipersist/version'
require_relative 'orm-multipersist/entity'

require 'active_model/attributes'

#class OrmPerson
#  include ActiveModel::Model
#  include ActiveModel::Attributes
#
#  attribute :name, :string
#end
#
#
#p = OrmPerson.new(name: 'John')
#p.name
#
