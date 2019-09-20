# frozen_string_literal: true

require_dependency 'claims_api/json_api_missing_attribute'

module ClaimsApi
  class FormSchemas
    BASE_DIR = Rails.root.join('modules', 'claims_api', Settings.claims_api.schema_dir)

    SCHEMAS = lambda do
      return_val = {}

      Dir.glob(File.join(BASE_DIR, '/*')).each do |schema|
        schema_name = File.basename(schema, '.json').upcase
        return_val[schema_name] = MultiJson.load(File.read(schema))
      end

      return_val
    end.call

    def self.date_validator
      lambda do |value|
        unless value.match?(/^(\d{4}|XXXX)-(0[1-9]|1[0-2]|XX)-(0[1-9]|[1-2][0-9]|3[0-1]|XX)$/)
          raise JSON::Schema::CustomFormatError, 'must be in format YYYY-MM-DD'
        end
      end
    end

    def self.address_line_validator
      lambda do |value|
        unless value.match?(/^([-a-zA-Z0-9'.,&#]([-a-zA-Z0-9'.,&# ])?)+$/)
          raise JSON::Schema::CustomFormatError, 'contains invalid characters'
        end
      end
    end

    def self.register_validators
      JSON::Validator.register_format_validator('date-pattern', date_validator)
      JSON::Validator.register_format_validator('address-line-pattern', address_line_validator)
    end

    def self.validate!(form, payload)
      register_validators
      errors = JSON::Validator.fully_validate(SCHEMAS[form], payload, errors_as_objects: true)
      raise ClaimsApi::JsonApiMissingAttribute, errors unless errors.empty?

      true
    end
  end
end
