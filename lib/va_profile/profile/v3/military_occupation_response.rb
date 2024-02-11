# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/military_occupation'

module VAProfile::Profile::V3
  class MilitaryOccupationResponse < VAProfile::Response
    attribute :military_occupations, Array[VAProfile::Models::MilitaryOccupation]
    attribute :messages, Array[VAProfile::Models::Message]

    def initialize(response)
      attributes = {
        military_occupations: response.body.dig('profile', 'military_person', 'military_occupations'),
        messages: response.body['messages']
      }

      super(response.status, attributes)
    end
  end
end
