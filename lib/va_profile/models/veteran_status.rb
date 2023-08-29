# frozen_string_literal: true

require_relative 'base'
# need this line?
require 'va_profile/concerns/defaultable'

module VAProfile
  module Models
    class VeteranStatus < Base
      include VAProfile::Concerns::Defaultable  # need this?

      attribute :combined_service_connected_rating_percentage, String
      # Might need to also grab the boolean serviceConnectedIndicator

      # Converts an instance of the VeteranStatus model to a JSON encoded string suitable for
      # use in the body of a request to VAProfile
      #
      # @return [String] JSON-encoded string suitable for requests to VAProfile
      def self.in_json
        {
          bios: [
            {
              bioPath: 'militaryPerson.militarySummary'
            }
          ]
        }.to_json
      end

      # Converts a decoded JSON response from VAProfile to an instance of the VeteranStatus model
      # @param rating [Hash] the decoded response rating from VAProfile
      # @return [VAProfile::Models::VeteranStatus] the model built from the response rating
      def self.build_veteran_status_rating(rating)
        return nil unless rating

        VAProfile::Models::VeteranStatus.new(
          combined_service_connected_rating_percentage: rating
        )
      end
    end
  end
end
