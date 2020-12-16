# frozen_string_literal: true

require 'json_marshal/marshaller'

module AppealsApi
  class NoticeOfDisagreement < ApplicationRecord
    include SentryLogging
    include CentralMailStatus

    REMOVE_PII = proc { update form_data: nil, auth_headers: nil }

    class << self
      def date_from_string(string)
        string.match(/\d{4}-\d{2}-\d{2}/) && Date.parse(string)
      rescue ArgumentError
        nil
      end

      def load_json_schema(filename)
        MultiJson.load File.read Rails.root.join('modules', 'appeals_api', 'config', 'schemas', "#{filename}.json")
      end

      # a json schemer error is a hash with this shape:
      #
      # {
      #   "type": "required",
      #   "details": {
      #     "missing_keys": ["addressLine1"]
      #   },
      #   "data_pointer": "/data/attributes/veteran/address",
      #   "data": {
      #     "addressLine2": "Suite #1200",
      #     "addressLine3": "Box 4",
      #     "city": "New York",
      #     "countryName": "United States",
      #     "stateCode": "NY",
      #     "zipCode5": "30012",
      #     "internationalPostalCode": "1"
      #   },
      #   "schema_pointer": "/definitions/nodCreateAddress",
      #   "schema": {
      #     "type": "object",
      #     "additionalProperties": false,
      #     "properties": {
      #       "addressLine1": {"type": "string"},
      #       "addressLine2": {"type": "string"},
      #       "addressLine3": {"type": "string"},
      #       "city": {"type": "string"},
      #       "stateCode": {"$ref": "#/definitions/nodCreateStateCode"},
      #       "countryName": {"type": "string"},
      #       "zipCode5": {"type": "string", "pattern": "^[0-9]{5}$"},
      #       "internationalPostalCode": {"type": "string"}
      #     },
      #     "required": [
      #       "addressLine1",
      #       "city",
      #       "countryName",
      #       "zipCode5"
      #     ]
      #   },
      #   "root_schema": {
      #     ... # entire schema
      #   }
      # }

      define_method :remove_pii, &REMOVE_PII
    end

    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    scope :has_pii, -> { where.not encrypted_form_data: nil, encrypted_auth_headers: nil }
    scope :has_not_been_updated_in_a_week, -> { where 'updated_at < ?', 1.week.ago }
    scope :ready_to_have_pii_expunged, -> { has_pii.completed.has_not_been_updated_in_a_week }

    validates :status, inclusion: { 'in': STATUSES }

    validate(
      :validate_address_unless_homeless,
      :validate_hearing_type_selection
    )

    def veteran_first_name
      header_field_as_string 'X-VA-First-Name'
    end

    def veteran_last_name
      header_field_as_string 'X-VA-Last-Name'
    end

    def ssn
      header_field_as_string 'X-VA-SSN'
    end

    def file_number
      header_field_as_string 'X-VA-File-Number'
    end

    def zip_code_5
      veteran_contact_info&.dig('address', 'zipCode5')
    end

    def veteran_contact_info
      form_data&.dig('data', 'attributes', 'veteran')
    end

    def consumer_name
      auth_headers&.dig('X-Consumer-Username')
    end

    def consumer_id
      auth_headers&.dig('X-Consumer-ID')
    end

    def board_review_option
      form_data&.dig('data', 'attributes', 'boardReviewOption')
    end

    def hearing_type_preference
      form_data&.dig('data', 'attributes', 'hearingTypePreference')
    end

    define_method :remove_pii, &REMOVE_PII

    private

    def validate_hearing_type_selection
      return if board_review_hearing_selected? && includes_hearing_type_preference?

      if hearing_type_missing?
        errors.add :form_data, I18n.t('appeals_api.errors.hearing_type_preference_missing')
      elsif unexpected_hearing_type_inclusion?
        errors.add :form_data, I18n.t('appeals_api.errors.hearing_type_preference_inclusion')
      end
    end

    def board_review_hearing_selected?
      board_review_option == 'hearing'
    end

    def includes_hearing_type_preference?
      hearing_type_preference.present?
    end

    def hearing_type_missing?
      board_review_hearing_selected? && !includes_hearing_type_preference?
    end

    def unexpected_hearing_type_inclusion?
      !board_review_hearing_selected? && includes_hearing_type_preference?
    end

    def validate_address_unless_homeless
      # TODO: the return solution needs to be improved
      return if veteran_contact_info.nil?

      contact_info = veteran_contact_info
      homeless = contact_info&.dig('homeless')
      address = contact_info&.dig('address')

      errors.add :form_data, I18n.t('appeals_api.errors.not_homeless_address_missing') if !homeless && address.nil?
    end

    def birth_date(who)
      self.class.date_from_string header_field_as_string "X-VA-#{who}-Birth-Date"
    end

    def header_field_as_string(key)
      auth_headers&.dig(key).to_s.strip
    end
  end
end
