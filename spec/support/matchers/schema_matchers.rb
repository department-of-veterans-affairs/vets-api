# frozen_string_literal: true

require 'rspec/expectations'

module SchemaMatchers
  extend RSpec::Matchers::DSL

  def valid_against_schema?(json, schema_name, opts = {})
    schema_path = Rails.root.join('spec', 'support', 'schemas', "#{schema_name}.json")
    JSON::Validator.validate!(schema_path.to_s, json, { strict: true }.merge(opts))
  end

  # TODO: don't actualy use this method, use the SchemaCamelizer to generate an alternate cameled-schema file
  # OliveBranch is used as middleware to allow the header 'X-Key-Inflection' to recieve 'camel'
  #  and return the response in camel format.  This method applies that tranform to a schema before
  #  using the JSON::Validator on the given json.  OliveBranch info @ https://github.com/vigetlabs/olive_branch
  def valid_against_olivebranched_schema?(json, schema_name, opts = {})
    schema_path = Rails.root.join('spec', 'support', 'schemas', "#{schema_name}.json")
    camel_schema = SchemaCamelizer.new(schema_path).camel_schema
    JSON::Validator.validate!(camel_schema, json, { strict: true }.merge(opts))
  end

  matcher :match_schema do |schema_name, opts = {}|
    match { |json| valid_against_schema?(json, schema_name, opts) }
  end

  matcher :match_response_schema do |schema_name, opts = {}|
    match { |response| valid_against_schema?(response.body, schema_name, opts) }
  end

  matcher :match_camelized_response_schema do |schema_name, opts = {}|
    match { |response| valid_against_olivebranched_schema?(response.body, schema_name, opts) }
  end

  matcher :match_vets_schema do |schema|
    match do |data|
      @errors = JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[schema], data, validate_schema: true)
      @errors.empty?
    end

    failure_message do |_actual|
      @errors
    end
  end

  class SchemaCamelizer
    def initialize(schema_path)
      raw_schema = File.read(schema_path)
      raw_schema.gsub!(/"required": \[(["\w*"\,? ?\n?]*)\]/) do |match|
        keys = $1.split(',').map(&:strip).map { |key| camelizer.call(key.gsub('"', '')) }
        "\"required\": [#{keys.map{ |key| "\"#{key}\"" }.join(', ')}]"
      end
      @camel_schema = JSON.parse(raw_schema)
      @cameled = false
    end

    def camel_schema
      unless @cameled
        OliveBranch::Transformations.transform(@camel_schema, camelizer)
        @cameled = true
      end
      @camel_schema
    end

    def camelizer
      OliveBranch::Transformations.method(:camelize)
    end
  end
end
