# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/v3/person'

module VAProfile
  module V2
    module ContactInformation
      class PersonResponse < VAProfile::Response
        attribute :person, VAProfile::Models::V3::Person

        attr_reader :response_body

        def self.from(raw_response = nil)
          response_body = raw_response&.body

          new(
            raw_response&.status,
            person: VAProfile::Models::V3::Person.build_from(response_body&.dig('bio'))
          )
        end

        def cache?
          super || (status >= 400 && status < 500)
        end
      end
    end
  end
end
