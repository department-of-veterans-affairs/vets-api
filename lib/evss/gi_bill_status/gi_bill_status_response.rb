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
      attribute :original_entitlement, Integer
      attribute :used_entitlement, Integer
      attribute :remaining_entitlement, Integer
      attribute :enrollments, Array[Enrollment]

      def initialize(status, response = nil)
        @response = response
        attributes = response.nil? ? {} : response.body['chapter33_education_info']
        super(status, attributes)
      end

      # EVSS partner is aware of user but has no info about them
      def contains_no_user_info?
        return false if @response.nil? || !@response&.body.key?('chapter33_education_info')
        @response&.body['chapter33_education_info'] == {}
      end

      # EVSS partner has never heard of user
      # response takes the form:
      # body=
      #   {"messages"=>
      #     [{"key"=>"education.chapter33claimant.partner.service.null",
      #       "severity"=>"WARN",
      #       "text"=>"Chapter33 Claimant partner service response is invalid"}]}
      def user_not_found?
        @response&.body&.dig('messages', 0, 'key') == 'education.chapter33claimant.partner.service.null' &&
          @response&.body&.dig('messages', 0, 'text') == 'Chapter33 Claimant partner service response is invalid'
      end
    end
  end
end
