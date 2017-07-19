# frozen_string_literal: true
require 'common/client/concerns/service_status'
require 'evss/response'

module EVSS
  module GiBillStatus
    class GiBillStatusResponse < EVSS::Response
      include SentryLogging

      attribute :first_name, String
      attribute :last_name, String
      attribute :name_suffix, String
      attribute :date_of_birth, String
      attribute :va_file_number, String
      attribute :regional_processing_office, String
      attribute :eligibility_date, String
      attribute :delimiting_date, String
      attribute :percentage_benefit, Integer
      attribute :original_entitlement, Entitlement
      attribute :used_entitlement, Entitlement
      attribute :remaining_entitlement, Entitlement
      attribute :veteran_is_eligible, Boolean
      attribute :active_duty, Boolean
      attribute :enrollments, Array[Enrollment]

      KNOWN_ERROR_KEYS = [
        'education.chapter33claimant.partner.service.down',
        'education.chapter33enrollment.partner.service.down',
        'education.partner.service.invalid',
        'education.service.error'
      ].freeze

      def initialize(status, response = nil, timeout = false, content_type = 'application/json')
        @timeout = timeout
        @response = response
        @content_type = content_type
        attributes = contains_education_info? ? response.body['chapter33_education_info'] : {}
        super(status, attributes)
      end

      def timeout?
        @timeout
      end

      def evss_error?
        contains_error_messages? && KNOWN_ERROR_KEYS.include?(error_key)
      end

      def contains_education_info?
        return false if @response.nil? || text_response?
        !vet_not_found? &&
          @response.body.key?('chapter33_education_info') == true &&
          @response.body['chapter33_education_info'] != {}
      end

      def vet_not_found?
        return false if @response.nil? || text_response?
        @response&.body == {}
      end

      def invalid_auth?
        # this one is a text/html response
        return false if @response.nil?
        @response&.body&.to_s&.include?('AUTH_INVALID_IDENTITY') || @response&.status == 403
      end

      private

      def contains_error_messages?
        return false if @response.nil? || text_response?
        @response&.body&.key?('messages') &&
          @response&.body['messages'].is_a?(Array) &&
          @response&.body['messages'].length.positive?
      end

      def error_key
        return nil if @response.nil?
        @response&.body['messages'][0]['key']
      end

      def text_response?
        @content_type.include?('text/html')
      end
    end
  end
end
