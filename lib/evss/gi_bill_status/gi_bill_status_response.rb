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
      attribute :veteran_is_eligible, Boolean
      attribute :active_duty, Boolean
      attribute :remaining_entitlement, Integer
      attribute :enrollments, Array[Enrollment]

      def initialize(status, response = nil)
        @response = response
        attributes = response.nil? || empty? ? {} : response.body['chapter33_education_info']
        super(status, attributes)
      end

      def empty?
        @response.body.nil? ||
          @response.body == {} ||
          @response.body.key?('chapter33_education_info') == false ||
          @response.body['chapter33_education_info'] == {}
      end
    end
  end
end
