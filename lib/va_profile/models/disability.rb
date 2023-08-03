# frozen_string_literal: true

require_relative 'base'
# need this line?
require 'va_profile/concerns/defaultable'

module VAProfile
  module Models
    class Disability < Base
      include VAProfile::Concerns::Defaultable  # need this?

      attribute :combined_service_connected_rating_percentage, String
      # Might need to also grab the boolean serviceConnectedIndicator

      # Converts an instance of the Disability model to a JSON encoded string suitable for
      # use in the body of a request to VAProfile
      #
      # @return [String] JSON-encoded string suitable for requests to VAProfile
      def self.in_json
        {
          bios: [
            {
              bioPath: 'disabilityRating'
            }
          ]
        }.to_json
      end

      # Converts a decoded JSON response from VAProfile to an instance of the Disability model
      # @param rating [Hash] the decoded response rating from VAProfile
      # @return [VAProfile::Models::Disability] the model built from the response rating
      def self.build_disability_data(rating)
        VAProfile::Models::Disability.new(
          combined_service_connected_rating_percentage: rating['combined_service_connected_rating_percentage']
        )
      end
      
      def self.build_from(rating)
        return nil unless rating

        build_disability_data(rating)
      end
    end
  end
end
