# frozen_string_literal: true

module Common
  class SchemaChecker
    def initialize(response, schema)
      @response = response
      @schema = schema
    end

    def validate
      errors = JSON::Validator.fully_validate(parsed_schema, parsed_response)

      if errors.any?
        details = error_details(errors)
        log_schema_errors(details)
      end
    end

    private

    def parsed_response
      JSON.parse(@response)
    rescue JSON::ParserError => e
      Rails.logger.error('Schema validator received invalid JSON response ', response: @response, details: e)
    end

    def parsed_schema
      file_contents = File.read(@schema)
      JSON.parse(file_contents)
    rescue Errno::ENOENT => e
      Rails.logger.error('Schema validation file not found', file: @schema, details: e)
    rescue JSON::ParserError => e
      Rails.logger.error('Schema validator received invalid JSON schema file ', file_contents:, details: e)
    end

    def error_details(details)
      { schema_file: @schema, response: @response, details: }
    end

    def log_schema_errors(details)
      Rails.logger.error('Schema discrepancy found', details:)
    end
  end
end