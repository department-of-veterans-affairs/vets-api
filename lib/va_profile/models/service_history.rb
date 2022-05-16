# frozen_string_literal: true

require_relative 'base'
require 'va_profile/concerns/defaultable'

module VAProfile
  module Models
    class ServiceHistory < Base
      include VAProfile::Concerns::Defaultable

      attribute :branch_of_service, String
      attribute :begin_date, String
      attribute :end_date, String
      attribute :personnel_category_type_code, String

      # Converts a decoded JSON response from VAProfile to an instance of the ServiceHistory model
      # @param body [Hash] the decoded response body from VAProfile
      # @return [VAProfile::Models::ServiceHistory] the model built from the response body
      def self.build_from(body)
        return nil unless body

        VAProfile::Models::ServiceHistory.new(
          branch_of_service: body['branch_of_service_text'],
          begin_date: body['period_of_service_begin_date'],
          end_date: body['period_of_service_end_date'],
          personnel_category_type_code: body['period_of_service_type_code']
        )
      end
    end
  end
end
