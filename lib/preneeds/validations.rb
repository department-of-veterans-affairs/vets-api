# frozen_string_literal: true
module Preneeds
  module Validations
    def self.military_rank_for_branch_of_service(params)
      validate(params, 'military_rank_request.json')
    end

    def self.validate(params, schema_name)
      schema = Settings.preneeds.schemas + schema_name
      errors = JSON::Validator.fully_validate(schema, params)

      errors_in_request?(errors)
    end

    def self.errors_in_request?(errors)
      return false if errors.blank?

      missing = errors&.map { |e| e.scan(%r{'#/\w*' did not contain a required property of '(\w+)' }) }&.flatten
      invalid = errors&.map { |e| e.scan(%r{'#/\w+/(\w+)'}) }&.flatten

      raise Common::Exceptions::ParameterMissing.new(missing.join(', '), detail: errors.join(', ')) if missing.present?
      raise Common::Exceptions::InvalidFieldValue.new(invalid.join(', '), detail: errors.join(', ')) if invalid.present?
      raise Common::Exceptions::InternalServerError, errors.join(', ')
    end
  end
end
