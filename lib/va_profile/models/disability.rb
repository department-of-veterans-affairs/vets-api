# frozen_string_literal: true

require_relative 'base'

module VAProfile
  module Models
    class Disability < Base
      attribute :combined_service_connected_rating_percentage, String
      validates :combined_service_connected_rating_percentage, presence: true, length: { maximum: 3 }

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
      def self.build_disability_rating(rating)
        return nil unless rating

        VAProfile::Models::Disability.new(
          combined_service_connected_rating_percentage: rating
        )
      end
    end
  end
end
