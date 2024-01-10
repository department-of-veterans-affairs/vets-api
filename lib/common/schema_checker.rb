# frozen_string_literal: true

module Common
  class SchemaChecker
    def initialize(response, schema)
      @response = response
      @schema = schema
    end

    def validate
      start_time = Time.zone.now
      # add feature flag check
      # return unless Rails.env.development?
      return unless @response.success?

      # validate file as well
      file = File.read(@schema)
      json_schema = JSON.parse(file)

      # for yaml: Openapi3Parser.load_file(schema_file)
      errors = JSON::Validator.fully_validate(json_schema, @response.response_body.to_json)

      if errors.any?
        details = error_details(errors)
        log_schema_errors(details)
      end
    # blanket rescue to ensure that this doesn't stop code execution 
    rescue => e
      Rails.logger.error('Schema validation internal error', details: error_details(e))
    ensure
      end_time = Time.zone.now
      elapsed_time = end_time - start_time
      Rails.logger.info('Schema validation time', schema_file: @schema, elapsed_time:)
    end

    def error_details(details)
      { schema_file: @schema, response: @response, details: }
    end

    def log_schema_errors(details)
      Rails.logger.error('Schema discrepancy found', details:)
    end
  end
end