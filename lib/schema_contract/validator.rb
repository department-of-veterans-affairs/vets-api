# frozen_string_literal: true

module SchemaContract
  class Validator
    class SchemaContractValidationError < StandardError; end

    def initialize(record_id)
      @record_id = record_id
    end

    def validate
      errors = JSON::Validator.fully_validate(parsed_schema, record.response)
      if errors.any?
        @result = 'schema_errors_found'
        error_message = 'Schema discrepancy found'
        record.update(error_details: errors)
        raise SchemaContractValidationError, error_message
        # Rails.logger.error(error_message, schema_file: @schema, response: @response, details:)
      else
        @result = 'success'
      end
    ensure
      # might need to tighten this up to avoid re-fetching the record if for some reason it's nil
      record&.update(status: @result) if defined?(@record)
    end

    private

    def record
      @record ||= SchemaContractTest.find(@record_id)
    end

    def schema_file
      path = Settings.schema_contract[record.name]
      raise SchemaContractValidationError, "No schema file #{record.name} found." if path.nil?

      Rails.root.join(path)
    end

    def parsed_schema
      file_contents = File.read(schema_file)
      JSON.parse(file_contents)
    end
  end
end