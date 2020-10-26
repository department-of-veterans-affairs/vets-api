# frozen_string_literal: true

module AppealsApi
  class NoticeOfDisagreement
    class << self
      def date_from_string(string)
        string.match(/\d{4}-\d{2}-\d{2}/) && Date.parse(string)
      rescue ArgumentError
        nil
      end

      def json_schemer_error_to_string(error)
        invalid_property = error['data_pointer'].presence || '/'

        reason = if detail['type'] == 'required'
                   "did not contain the required key #{error['details']['missing_key']}"
                 else
                   "did not match the following requirements #{detail['schema']}"
                 end

        "The property #{invalid_property} #{reason}"
      end

      def load_schema(filename)
        MultiJson.load File.read Rails.root.join('modules', 'appeals_api', 'config', 'schemas', "#{filename}.json")
      end

      # returns errors array
      def validate_against_schema(hash, schema:)
        JSONSchemer.schema(schema).validate(hash).to_a
      end
    end

    FORM_SCHEMA = load_schema '10182'
    AUTH_HEADERS_SCHEMA = load_schema '10182_headers'

    attr_reader :form_data, :auth_headers

    def initialize(form_data:, auth_headers:)
      @form_data = form_data
      @auth_headers = auth_headers
      validate
    end

    def validate
      validate_against_schemas && validate_that_claimant_info_is_complete_or_absent
    end

    # adds to model errors
    def validate_against_schemas
      (
        validate_against_schema(data: form_data, schema: FORM_SCHEMA, attribute_name: :form_data) +
        validate_against_schema(data: auth_headers, schema: AUTH_HEADERS_SCHEMA, attribute_name: :auth_headers)
      ).blank?
    end

    # adds to model errors
    def validate_against_schema(data:, schema:, attribute_name:)
      errors = self.class.validate_against_schema data, schema: schema
      add_errors errors, attribute_name: attribute_name
      errors
    end

    # adds to model errors
    def validate_claimant_properly_included_or_absent?
      return true if claimant_properly_included_or_absent?

      # at least 1 piece is missing (name, birth_date, or contact info)

      add_missing_claimant_info_error 'name', attribute_name: :auth_headers if claimant_name.blank?
      add_missing_claimant_info_error 'birth date', attribute_name: :auth_headers if claimant_birth_date.blank?
      if claimant_contact_info.blank?
        add_missing_claimant_info_error 'contact info (data/attributes/claimant)', attribute_name: :form_data
      end
      false
    end

    def claimant_properly_included_or_absent?
      required_claimant_fields_are_all_present? || all_claimant_fields_blank?
    end

    def required_claimant_fields_are_all_present?
      claimant_name.present? && claimant_birth_date.present? && claimant_contact_info.present?
    end

    def all_claimant_fields_blank?
      claimant_name.blank? && claimant_birth_date.blank? && claimant_contact_info.blank?
    end

    def claimant_contact_info
      form_data&.dig('data', 'attributes', 'claimant')
    end

    def add_missing_claimant_info_error(field, attribute_name:)
      errors.add attribute_name, "if any claimant info is present, claimant #{field} must also be present"
    end

    def claimant_birth_date
      birth_date 'Claimant'
    end

    def birth_date(who)
      self.class.date_from_string header_field_as_string "X-VA-#{who}-Birth-Date"
    end

    def claimant_name
      name 'Claimant'
    end

    def name(who)
      [
        first_name(who),
        middle_initial(who),
        last_name(who)
      ].map(&:presence).compact.map(&:strip).join(' ')
    end

    def first_name(who)
      header_field_as_string "X-VA-#{who}-First-Name"
    end

    def middle_initial(who)
      header_field_as_string "X-VA-#{who}-Middle-Initial"
    end

    def last_name(who)
      header_field_as_string "X-VA-#{who}-Last-Name"
    end

    def header_field_as_string(key)
      header_field(key).to_s.strip
    end

    def header_field(key)
      auth_headers&.dig(key)
    end

    def add_errors(messages, attribute_name: :base)
      messages.each { |m| errors.add(attribute_name, m) }
    end
  end
end
