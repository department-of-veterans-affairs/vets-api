# frozen_string_literal: true

module JsonSchema
  class JsonApiMissingAttribute < StandardError
    attr_accessor :code, :details

    def initialize(details)
      @code = 422
      @details = details
    end

    def to_human(detail)
      if detail['type'] == 'required'
        "The property #{to_source(detail)} did not contain the required key #{detail['details']['missing_key']}"
      elsif detail['type'] == 'schema' && detail['schema_pointer'].end_with?('additionalProperties')
        "The property #{to_source(detail)} is not defined on the schema. Additional properties are not allowed"
      else
        "The property #{detail['data_pointer']} did not match the following requirements: #{detail['schema']}"
      end
    end

    def to_source(detail)
      detail['data_pointer'].empty? ? '/' : detail['data_pointer']
    end

    def build_error(detail)
      {
        status: 422,
        detail: to_human(detail),
        source: to_source(detail)
      }
    end

    def build_required_errors(required_error)
      required_error['details']['missing_keys'].map do |missing_key|
        build_error(
          'type' => 'required',
          'data_pointer' => required_error['data_pointer'],
          'details' => { 'missing_key' => missing_key }
        )
      end
    end

    def required_error?(detail)
      detail['type'] == 'required'
    end

    def to_json_api
      required_errors = details.select { |detail| required_error?(detail) }
      other_errors = details.reject { |detail| required_error?(detail) }
      errors = []
      unless required_errors.empty?
        errors.concat(required_errors.map { |error| build_required_errors(error) }.reduce(:concat))
      end
      errors.concat(other_errors.map { |error| build_error(error) })
      { errors: }
    end
  end
end
