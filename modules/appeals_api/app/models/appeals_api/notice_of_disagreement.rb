# frozen_string_literal: true

require 'json_marshal/marshaller'
require 'common/exceptions'

module AppealsApi
  class NoticeOfDisagreement < ApplicationRecord
    include CentralMailStatus

    def self.load_json_schema(filename)
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

    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    validate :validate_hearing_type_selection

    def veteran_first_name
      header_field_as_string 'X-VA-Veteran-First-Name'
    end

    def veteran_last_name
      header_field_as_string 'X-VA-Veteran-Last-Name'
    end

    def ssn
      header_field_as_string 'X-VA-Veteran-SSN'
    end

    def file_number
      header_field_as_string 'X-VA-Veteran-File-Number'
    end

    def consumer_name
      header_field_as_string 'X-Consumer-Username'
    end

    def consumer_id
      header_field_as_string 'X-Consumer-ID'
    end

    def veteran_homeless_state
      form_data&.dig('data', 'attributes', 'veteran', 'homeless')
    end

    def veteran_representative
      form_data&.dig('data', 'attributes', 'veteran', 'representativesName')
    end

    def board_review_option
      form_data&.dig('data', 'attributes', 'boardReviewOption')
    end

    def hearing_type_preference
      form_data&.dig('data', 'attributes', 'hearingTypePreference')
    end

    def zip_code_5
      form_data&.dig('data', 'attributes', 'veteran', 'address', 'zipCode5')
    end

    private

    def validate_hearing_type_selection
      return if board_review_hearing_selected? && includes_hearing_type_preference?

      source = '/data/attributes/hearingTypePreference'
      data = I18n.t('common.exceptions.validation_errors')

      if hearing_type_missing?
        errors.add source, data.merge(detail: I18n.t('appeals_api.errors.hearing_type_preference_missing'))
      elsif unexpected_hearing_type_inclusion?
        errors.add source, data.merge(detail: I18n.t('appeals_api.errors.hearing_type_preference_inclusion'))
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

    def birth_date(who)
      self.class.date_from_string header_field_as_string "X-VA-#{who}-Birth-Date"
    end

    def header_field_as_string(key)
      auth_headers&.dig(key).to_s.strip
    end
  end
end
