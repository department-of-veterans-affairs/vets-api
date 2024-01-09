# frozen_string_literal: true

module Common
  class SchemaChecker
    def initialize(response, schema)
      @response = response
      @schema = schema
    end

    def validate
      # return unless Rails.env.development?
      return unless @response.success?

      # validate file as well
      file = File.read(@schema)
      json_schema = JSON.parse(file)

binding.pry

      # Openapi3Parser.load_file(schema_file)
      errors = JSON::Validator.fully_validate(json_schema, @response.response_body.to_json, strict: true)
      if errors.any?
        log_errors
      end
    end

    def log_errors
    end
  end
end