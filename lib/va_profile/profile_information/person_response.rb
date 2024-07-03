# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/person'

module VAProfile
  module ProfileInformation
    class PersonResponse < VAProfile::Response
      attribute :person, VAProfile::Models::Person
      attribute :messages, Array[VAProfile::Models::Message]

      def initialize(response)
        body = response.body
        person =  body.dig('profile', 'bio')
        messages = body['messages']
        va_profile_tx_audit_id = response.response_headers['vaprofiletxauditid']
        super(response.status, { person:, messages:, va_profile_tx_audit_id: })
      end

      # def self.from(raw_response = nil)
      #   @response_body = raw_response&.body

      #   new(
      #     raw_response&.status,
      #     person: VAProfile::Models::Person.build_from(@response_body&.dig('bio'))
      #   )
      # end

      # def cache?
      #   super || (status >= 400 && status < 500)
      # end

      private

      def message
        m = messages&.first
        return '' unless m

        "#{m.code} #{m.key} #{m.text}"
      end
    end
  end
end