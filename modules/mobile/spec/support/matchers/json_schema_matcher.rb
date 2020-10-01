# frozen_string_literal: true

require 'rspec/expectations'

module JsonSchemaMatchers
  extend RSpec::Matchers::DSL

  matcher :match_json_schema do |schema_name, options = {}|
    schema_path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'schemas', "#{schema_name}.json").to_s
    match { |data| JSON::Validator.validate!(schema_path, data, options) }
  end
end
