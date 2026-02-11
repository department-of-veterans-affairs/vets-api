# frozen_string_literal: true

require_relative 'base'
require 'va_profile/concerns/defaultable'

module VAProfile
  module Models
    class DodServiceSummary < Base
      include VAProfile::Concerns::Defaultable

      attribute :dod_service_summary_code, String
      attribute :calculation_model_version, String
      attribute :effective_start_date, String

      # Converts an instance of the DodServiceSummary model to a JSON encoded string suitable for
      # use in the body of a request to VAProfile
      #
      # @return [String] JSON-encoded string suitable for requests to VAProfile
      def self.in_json
        {
          bios: [
            {
              bioPath: 'militaryPerson.militarySummary.customerType.dodServiceSummary'
            }
          ]
        }.to_json
      end
    end
  end
end
