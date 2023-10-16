# frozen_string_literal: true

require 'va_profile/response'
require_relative '../models/veteran_status'

module VAProfile
  module VeteranStatus
    class VeteranStatusResponse < VAProfile::Response
      attribute :title38_status_code, VAProfile::Models::VeteranStatus

      def self.from(_, response = nil)
        body = response&.body

        title38_status_code = body&.dig(
          'profile', 'military_person',
          'military_summary', 'title38_status_code'
        )
        new(
          response&.status,
          title38_status_code: VAProfile::Models::VeteranStatus.new(
            title38_status_code:
          )
        )
      end
    end
  end
end
