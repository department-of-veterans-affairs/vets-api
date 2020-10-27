# frozen_string_literal: true

require 'json_marshal/marshaller'

module AppealsApi
  class NoticeOfDisagreement < ApplicationRecord
    include SentryLogging

    class << self
      def date_from_string(string)
        string.match(/\d{4}-\d{2}-\d{2}/) && Date.parse(string)
      rescue ArgumentError
        nil
      end

      def load_json_schema(filename)
        MultiJson.load File.read Rails.root.join('modules', 'appeals_api', 'config', 'schemas', "#{filename}.json")
      end

      def json_schemer_error_to_string(error)
        path = error['data_pointer'].presence || '/'

        reason = if error['type'] == 'required'
                   "did not contain the required key #{error.dig('details', 'missing_key')}"
                 else
                   "did not match the following requirements: #{error['schema']}"
                 end

        "The property \"#{path}\" #{reason}"
      end
    end

    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    FORM_SCHEMA = load_json_schema '10182'
    AUTH_HEADERS_SCHEMA = load_json_schema '10182_headers'

    validate(
      :validate_auth_headers_against_schema,
      :validate_form_data_against_schema,
      :validate_claimant_properly_included_or_absent,
      :validate_that_at_least_one_set_of_contact_info_is_present
    )

    def claimant_name
      name 'Claimant'
    end

    def claimant_birth_date
      birth_date 'Claimant'
    end

    def claimant_contact_info
      form_data&.dig('data', 'attributes', 'claimant')
    end

    def veteran_contact_info
      form_data&.dig('data', 'attributes', 'veteran')
    end

    private

    def validate_auth_headers_against_schema
      validate_against_schema data: auth_headers, schema: AUTH_HEADERS_SCHEMA, attribute_name: :auth_headers
    end

    def validate_form_data_against_schema
      validate_against_schema data: form_data, schema: FORM_SCHEMA, attribute_name: :form_data
    end

    def validate_against_schema(data:, schema:, attribute_name:)
      JSONSchemer.schema(schema).validate(data || {}).to_a
                 .map { |error| self.class.json_schemer_error_to_string error }
                 .each { |error_message| errors.add attribute_name, error_message }
    end

    def validate_claimant_properly_included_or_absent
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

    def add_missing_claimant_info_error(field, attribute_name:)
      errors.add attribute_name, "if any claimant info is present, claimant #{field} must also be present"
    end

    def validate_that_at_least_one_set_of_contact_info_is_present
      return if veteran_contact_info.present? || claimant_contact_info.present?

      errors.add :form_data, "at least one must be incuded: '/data/attributes/veteran', '/data/attributes/claimant'"
    end

    def birth_date(who)
      self.class.date_from_string header_field_as_string "X-VA-#{who}-Birth-Date"
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
  end
end
