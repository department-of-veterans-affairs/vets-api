# frozen_string_literal: true
require 'rspec/expectations'

module MobileSchemaMatchers
  extend RSpec::Matchers::DSL

  def valid_against_schema?(json, schema_name, opts = {})
    schema_path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'schemas', "#{schema_name}.json")
    JSON::Validator.validate!(schema_path.to_s, json, {strict: false}.merge(opts))
  end

  matcher :match_schema do |schema_name, opts = {}|
    match { |json| valid_against_schema?(json, schema_name, opts) }
  end

  matcher :match_response_schema do |schema_name, opts = {}|
    match { |response| valid_against_schema?(response.body, schema_name, opts) }
  end
end
