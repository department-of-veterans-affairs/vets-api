# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/veteran_status'

module VAProfile
  module VeteranStatus
    class VeteranStatusResponse < VAProfile::Response
      attribute :veteran_status_title, VAProfile::Models::VeteranStatus

      def self.from(_, raw_response = nil)
        body = raw_response&.body
        veteran_status_title = get_title(body)

        new(
          raw_response&.status,
          veteran_status_title: veteran_status_title
        )
      end

      def self.get_title(body)
        return nil unless body

        combined_service_connected_title = body&.dig(
          'profile',
          'veteran_status_title'
        )

        VAProfile::Models::VeteranStatus.build_veteran_status_title(
          combined_service_connected_title
        )
      end
    end
  end
end
