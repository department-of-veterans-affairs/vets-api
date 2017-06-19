# frozen_string_literal: true
require 'common/client/concerns/service_status'
require 'evss/response'

module EVSS
  module GiBillStatus
    class GiBillStatusResponse < EVSS::Response
      include Common::Client::ServiceStatus

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
      attribute :enrollments, Array[Object]

      def initialize(status, raw_response = nil)
        super(status)
        if raw_response
          self.attributes.each do |a|
            self.attributes
          end
          self.first_name = raw_response.body['first_name']
          self.last_name = raw_response.body['last_name']
          self.name_suffix = raw_response.body['name_suffix']
          self.date_of_birth = raw_response.body['date_of_birth']
          self.va_file_number = raw_response.body['va_file_number']
          self.regional_processing_office = raw_response.body['regional_processing_office']
          self.eligibility_date = raw_response.body['eligibility_date']
          self.delimiting_date = raw_response.body['delimiting_date']
          self.percentage_benefit = raw_response.body['percentage_benefit']
          self.original_entitlement = raw_response.body['original_entitlement']
          self.used_entitlement = raw_response.body['used_entitlement']
          self.remaining_entitlement = raw_response.body['remaining_entitlement']
          self.enrollments = raw_response.body['enrollments']
        end
      end
    end
  end
end
