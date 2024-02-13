# frozen_string_literal: true

module SchemaContract
  class Validator
    def initialize(record_id)
      @record_id = record_id
    end

    def validate
      errors = JSON::Validator.fully_validate(parsed_schema, parsed_response)
      if errors.any?
        @result = 'schema_errors_found'
        Rails.logger.error('Schema discrepancy found', schema_file: @schema, response: @response, details:)
      else
        @result = 'success'
      end
    ensure
      # might need to tighten this up to avoid re-fetching the record if for some reason it's nil
      record&.update(status: @result)
    end

    private

    def record
      @record ||= SchemaContract.find(id: @record_id)
    end

    def schema_file
      "#{Settings.schema_contract.appointments_index.path}_#{@test_name}.json"
    end

    def parsed_response
      # this is probably no longer necessary
      JSON.parse(record.response)
    rescue JSON::ParserError => e
      @result = 'invalid_response'
      Rails.logger.error('Schema validator received invalid JSON response ', response: record.response, details: e)
    end

    def parsed_schema
      file_contents = File.read(schema_file)
      JSON.parse(file_contents)
    rescue Errno::ENOENT => e
      @result = 'validation_file_not_found'
      Rails.logger.error('Schema validation file not found', schema_file:, details: e)
    rescue JSON::ParserError => e
      @result = 'invalid_schema_file'
      Rails.logger.error('Schema validator received invalid JSON schema file ', file_contents:, details: e)
    end
  end
end