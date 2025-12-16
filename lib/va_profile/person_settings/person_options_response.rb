# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/person_option'

module VAProfile
  module PersonSettings
    class PersonOptionsResponse < VAProfile::Response
      attribute :person_options, Array

      def self.from(raw_response = nil)
        response_body = raw_response&.body
        person_options = if response_body&.dig('bios')
                           response_body['bios'].map { |bio| VAProfile::Models::PersonOption.build_from(bio) }
                         else
                           []
                         end

        new(
          raw_response&.status,
          person_options:
        )
      end
    end
  end
end
