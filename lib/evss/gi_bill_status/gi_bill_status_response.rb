# frozen_string_literal: true
require 'common/client/concerns/service_status'
require 'evss/response'

module EVSS
  module GiBillStatus
    class GiBillStatusResponse < EVSS::Response
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
        attributes = response.nil? ? {} : response.body['chapter33_education_info']
        super(status, attributes)
      end
    end
  end
end
