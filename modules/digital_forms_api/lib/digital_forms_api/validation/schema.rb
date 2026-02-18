# frozen_string_literal: true

require 'json-schema'

module DigitalFormsApi
  module Validation
    module_function

    # Utility function to validate a value against a given JSON schema
    # @param schema [Hash] the JSON schema to validate against
    # @param value [Mixed] the value to be validated against the schema
    # @return [Mixed] the validated value if it conforms to the schema
    # @raise [JSON::Schema::ValidationError] if the value does not conform to the schema
    # or if there is an error in the schema itself
    # @example
    #   schema = {
    #     "type" => "object",
    #     "properties" => {
    #       "contentName" => { "type" => "string" },
    #       "providerData" => { "type" => "object" }
    #     },
    #     "required" => ["contentName", "providerData"]
    #   }
    #   value = { contentName: 'test.pdf', providerData: { key: 'value' } }
    #   validate_against_schema(schema, value) # => returns the value if it is valid according to the schema
    #   invalid_value = { contentName: 'test.pdf' }
    #   validate_against_schema(schema, invalid_value) # => raises JSON::Schema::ValidationError
    #   because providerData is required
    def validate_against_schema(schema, value)
      JSON::Validator.validate!(schema, value)
      value
    end
  end
end
