# frozen_string_literal: true

require 'common/client/concerns/service_status'
require 'evss/gi_bill_status/enrollment'
require 'evss/gi_bill_status/entitlement'
require 'evss/response'

module EVSS
  module GiBillStatus
    ##
    # Model for the GIBS status response
    #
    # @!attribute first_name
    #   @return [String] User's first name
    # @!attribute last_name
    #   @return [String] User's last name
    # @!attribute name_suffix
    #   @retun [String] User's suffix
    # @!attribute date_of_birth
    #   @return [String] User's date of birth
    # @!attribute va_file_number
    #   @return [String] User's VA file number
    # @!attribute regional_processing_office
    #   @return [String] Closest processing office to the user
    # @!attribute eligibility_date
    #   @return [String] The date at which benefits are eligible to be paid
    # @!attribute delimiting_date
    #   @return [String] The date after which benefits cannot be paid
    # @!attribute percentage_benefit
    #   @return [Integer] The amount of the benefit the user is eligible for
    # @!attribute original_entitlement
    #   @return [Entitlement] The time span of the user's original entitlement
    # @!attribute used_entitlement
    #   @return [Entitlement] The amount of entitlement time the user has already used
    # @!attribute remaining_entitlement
    #   @return [Entitlement] The amount of entitlement time the user has remaining
    # @!attribute veteran_is_eligible
    #   @return [Boolean] Is the user eligbile for the benefit
    # @!attribute active_duty
    #   @return [Boolean] Is the user on active duty
    # @!attribute enrollments
    #   @return [Array[Enrollment]] An array of the user's enrollments
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

      EVSS_ERROR_KEYS = [
        'education.chapter33claimant.partner.service.down',
        'education.chapter33enrollment.partner.service.down',
        'education.partner.service.invalid',
        'education.service.error'
      ].freeze

      KNOWN_ERRORS = {
        evss_error: 'evss_error',
        vet_not_found: 'vet_not_found',
        timeout: 'timeout',
        invalid_auth: 'invalid_auth'
      }.freeze

      ##
      # Create an instance of GiBillStatusResponse
      #
      # @param status [Integer] The HTTP status code from the service
      # @param response [String] The raw endpoint response or error body
      # @param timeout [Boolean] If the response timed out
      # @param content_type [String] The content type
      #
      def initialize(status, response = nil, timeout = false, content_type = 'application/json')
        @timeout = timeout
        @response = response
        @content_type = content_type
        attributes = contains_education_info? ? response.body['chapter33_education_info'] : {}
        super(status, attributes)
      end

      ##
      # @return [Time] The response timestamp in UTC
      #
      def timestamp
        Time.parse(@response.response_headers['date']).utc
      end

      ##
      # @return [Boolean] Checks if the response is correctly formatted and contains
      # the expected educational information
      def success?
        contains_education_info?
      end

      ##
      # @return [String] The response error type
      def error_type
        KNOWN_ERRORS.each_value do |error_val|
          return error_val if send("#{error_val}?")
        end

        'unknown'
      end

      private

      def timeout?
        @timeout
      end

      def evss_error?
        contains_error_messages? && EVSS_ERROR_KEYS.include?(evss_error_key)
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

      def contains_education_info?
        return false if @response.nil? || text_response?

        !vet_not_found? &&
          @response.body.key?('chapter33_education_info') == true &&
          @response.body['chapter33_education_info'] != {} &&
          !@response.body['chapter33_education_info'].nil?
      end

      def contains_error_messages?
        return false if @response&.body.nil? || text_response?

        @response.body.key?('messages') &&
          @response.body['messages'].is_a?(Array) &&
          @response.body['messages'].length.positive?
      end

      def evss_error_key
        return nil if @response&.body.nil?

        @response.body.dig('messages', 0, 'key')
      end

      def text_response?
        @content_type.include?('text/html') || !@response.body.respond_to?(:key?)
      end
    end
  end
end
