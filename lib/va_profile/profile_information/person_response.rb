# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/person'

module VAProfile
  module ProfileInformation
    class PersonResponse < VAProfile::Response
      attribute :person, VAProfile::Models::Person
      attribute :messages, Array[VAProfile::Models::Message]

      def initialize(response)
        attributes = {
          person: response.body.dig('profile', 'bio'),
          messages: response.body['messages']
        }

        super(response.status, attributes)
      end
    end
  end
end
