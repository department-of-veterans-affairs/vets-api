# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/demographic'

module VAProfile
  module Demographics
    class DemographicResponse < VAProfile::Response
      attribute :demographics, VAProfile::Models::Demographic

      def self.from(raw_response = nil)
        response_body = raw_response&.body

        new(
          raw_response&.status,
          demographics: VAProfile::Models::Demographic.build_from(response_body&.dig('bio'))
        )
      end
    end
  end
end
