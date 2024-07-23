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
        record.update(error_details: errors)
        detailed_message = { error_type: 'Schema discrepancy found', record_id: @record_id, response: record.response,
                             details: errors }
        raise SchemaContractValidationError, detailed_message
      else
        @result = 'success'
      end
    rescue SchemaContractValidationError => e
      raise e
    rescue => e
      @result = 'error'
      detailed_message = { error_type: 'Unknown', record_id: @record_id, details: e.message }
      raise SchemaContractValidationError, detailed_message
    ensure
      record&.update(status: @result) if defined?(@record)
    end

    private

    def record
      @record ||= Validation.find(@record_id)
    end

    def schema_file
      @schema_file ||= begin
        path = Settings.schema_contract[record.contract_name]
        if path.nil?
          @result = 'schema_not_found'
          raise SchemaContractValidationError, "No schema file #{record.contract_name} found."
        end

        Rails.root.join(path)
      end
    end

    def parsed_schema
      file_contents = File.read(schema_file)
      JSON.parse(file_contents)
    end
  end
end
