# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/preferred_name'

module VAProfile
  module Demographics
    class PreferredNameResponse < VAProfile::Response
      attribute :preferred_name, VAProfile::Models::PreferredName

      def text
        preferred_name&.text
      end

      def self.from(raw_response = nil)
        response_body = raw_response&.body

        new(
          raw_response&.status,
          preferred_name: VAProfile::Models::PreferredName.build_from(response_body)
        )
      end
    end
  end
end
