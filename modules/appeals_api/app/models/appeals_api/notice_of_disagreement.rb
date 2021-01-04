# frozen_string_literal: true

require 'json_marshal/marshaller'
require 'common/exceptions'

module AppealsApi
  class NoticeOfDisagreement < ApplicationRecord
    include SentryLogging

    REMOVE_PII = proc { update form_data: nil, auth_headers: nil }

    class << self
      def refresh_statuses_using_central_mail!(notice_of_disagreement)
        return if notice_of_disagreement.empty?

        response = CentralMail::Service.new.status(notice_of_disagreement.pluck(:id))
        unless response.success?
          log_bad_central_mail_response(response)
          raise Common::Exceptions::BadGateway
        end

        central_mail_status_objects = parse_central_mail_response(response).select { |s| s.id.present? }
        ActiveRecord::Base.transaction do
          central_mail_status_objects.each do |obj|
            notice_of_disagreement.find { |h| h.id == obj.id }
                                  .update_status_using_central_mail_status!(obj.status, obj.error_message)
          end
        end
      end

      def log_unknown_central_mail_status(status)
        log_message_to_sentry('Unknown status value from Central Mail API', :warning, status: status)
      end

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

      private

      def parse_central_mail_response(response)
        JSON.parse(response.body).flatten.map do |hash|
          Struct.new(:id, :status, :error_message).new(*hash.values_at('uuid', 'status', 'errorMessage'))
        end
      end

      def log_bad_central_mail_response(resp)
        log_message_to_sentry('Error getting status from Central Mail', :warning, status: resp.status, body: resp.body)
      end
    end

    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    STATUSES = %w[pending submitting submitted processing error uploaded received success expired].freeze

    validates :status, inclusion: { 'in': STATUSES }

    CENTRAL_MAIL_STATUS_TO_NOD_ATTRIBUTES = lambda do
      hash = Hash.new { |_, _| raise ArgumentError, 'Unknown Central Mail status' }
      hash['Received'] = { status: 'received' }
      hash['In Process'] = { status: 'processing' }
      hash['Processing Success'] = hash['In Process']
      hash['Success'] = { status: 'success' }
      hash['Error'] = { status: 'error', code: 'DOC202' }
      hash['Processing Error'] = hash['Error']
      hash
    end.call.freeze
    # ensure that statuses in map are valid statuses
    raise unless CENTRAL_MAIL_STATUS_TO_NOD_ATTRIBUTES.values.all? do |attributes|
      [:status, 'status'].all? do |status|
        !attributes.key?(status) || attributes[status].in?(STATUSES)
      end
    end

    CENTRAL_MAIL_ERROR_STATUSES = ['Error', 'Processing Error'].freeze
    raise unless CENTRAL_MAIL_ERROR_STATUSES - CENTRAL_MAIL_STATUS_TO_NOD_ATTRIBUTES.keys == []

    RECEIVED_OR_PROCESSING = %w[received processing].freeze
    raise unless RECEIVED_OR_PROCESSING - STATUSES == []

    COMPLETE_STATUSES = %w[success error].freeze
    raise unless COMPLETE_STATUSES - STATUSES == []

    scope :received_or_processing, -> { where status: RECEIVED_OR_PROCESSING }
    scope :completed, -> { where status: COMPLETE_STATUSES }
    scope :has_pii, -> { where.not(encrypted_form_data: nil).or(where.not(encrypted_auth_headers: nil)) }
    scope :has_not_been_updated_in_a_week, -> { where 'updated_at < ?', 1.week.ago }
    scope :ready_to_have_pii_expunged, -> { has_pii.completed.has_not_been_updated_in_a_week }

    validate :validate_hearing_type_selection

    def update_status_using_central_mail_status!(status, error_message = nil)
      begin
        attributes = CENTRAL_MAIL_STATUS_TO_NOD_ATTRIBUTES[status] || {}
      rescue ArgumentError
        self.class.log_unknown_central_mail_status(status)
        raise Common::Exceptions::BadGateway, detail: 'Unknown processing status'
      end
      if status.in?(CENTRAL_MAIL_ERROR_STATUSES) && error_message
        attributes = attributes.merge(detail: "Downstream status: #{error_message}")
      end

      update! attributes
    end

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

    def veteran_homeless_state
      form_data&.dig('data', 'attributes', 'veteran', 'homeless')
    end

    def veteran_representative
      form_data&.dig('data', 'attributes', 'veteran', 'representativesName')
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
