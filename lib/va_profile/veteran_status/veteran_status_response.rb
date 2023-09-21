# frozen_string_literal: true

require 'va_profile/response'
require_relative '../models/veteran_status'

module VAProfile
  module VeteranStatus
    class VeteranStatusResponse < VAProfile::Response
      attribute :title38_status_code, VAProfile::Models::VeteranStatus

      def self.from(_, raw_response = nil)
        body = raw_response&.body

        title38_status_code = body&.dig('profile', 'military_person', 'military_summary', 'title38_status_code')  # parse title_38 from the raw response
        new(
            raw_response&.status,
            title38_status_code: VAProfile::Models::VeteranStatus.new(
             title38_status_code: title38_status_code
           )
         )
      end
    end
  end
end
