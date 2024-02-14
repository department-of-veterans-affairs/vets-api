# frozen_string_literal: true

module SchemaContract
  class Validator


    class SchemaContractValidationError < StandardError; end

    def initialize(record_id)
      @record_id = record_id
    end

    def validate
      errors = JSON::Validator.fully_validate(parsed_schema, parsed_response)
      if errors.any?
        @result = 'schema_errors_found'
        error_message = 'Schema discrepancy found'
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
      @record ||= SchemaContractTest.find(id: @record_id)
    end

    def schema_file
      join(Settings.schema_contract.appointments_index.path, "#{@test_name}.json")
    end

    def parsed_response
      # this is probably no longer necessary
      JSON.parse(record.response)
    rescue JSON::ParserError => e
      @result = 'invalid_response'
      error_message = 'Schema validator received invalid JSON response'
      raise SchemaContractValidationError, error_message
      # Rails.logger.error(error_message, response: record.response, details: e)
    end

    def parsed_schema
      file_contents = File.read(schema_file)
      JSON.parse(file_contents)
    rescue Errno::ENOENT => e
      @result = 'validation_file_not_found'
      error_message = 'Schema validation file not found'
      raise SchemaContractValidationError, error_message
      # Rails.logger.error(error_message, schema_file:, details: e)
    rescue JSON::ParserError => e
      @result = 'invalid_schema_file'
      error_message = 'Schema validator received invalid JSON schema file'
      raise SchemaContractValidationError, error_message
      # Rails.logger.error(error_message, file_contents:, details: e)
    end
  end
end