# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/veteran_status'

module VAProfile
  module VeteranStatus
    class VeteranStatusResponse < VAProfile::Response
      attribute :veteran_status_rating, VAProfile::Models::VeteranStatus

      def self.from(_, raw_response = nil)
        body = raw_response&.body
        veteran_status_rating = get_rating(body)

        new(
          raw_response&.status,
          veteran_status_rating: veteran_status_rating
        )
      end

      def self.get_rating(body)
        return nil unless body

        combined_service_connected_rating_percentage = body&.dig(
          'profile',
          'veteran_status_rating',
          'combined_service_connected_rating_percentage'
        )

        VAProfile::Models::VeteranStatus.build_veteran_status_rating(
          combined_service_connected_rating_percentage
        )
      end
    end
  end
end
