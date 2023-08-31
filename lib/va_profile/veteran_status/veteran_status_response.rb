# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/veteran_status'

module VAProfile
  module VeteranStatus
    class VeteranStatusResponse < VAProfile::Response
      attribute :veteran_status_title, VAProfile::Models::VeteranStatus

      def self.from(_, raw_response = nil)
        body = raw_response&.body

        title_38_status_code = body&.dig('profile', 'militaryPerson', 'militarySummary', 'title38StatusCode')  # parse title_38 from the raw response

        new(
          raw_response&.status,
          veteran_status_title: VAProfile::Models::VeteranStatus.new(
            title_38_status_code: title_38_status_code
          )
        )
      end
    end
  end
end
