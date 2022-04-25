# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/gender_identity'

module VAProfile
  module Demographics
    class GenderIdentityResponse < VAProfile::Response
      attribute :gender_identity, VAProfile::Models::GenderIdentity

      def code
        gender_identity&.code
      end

      def name
        gender_identity&.name
      end

      def self.from(raw_response = nil)
        response_body = raw_response&.body

        new(
          raw_response&.status,
          gender_identity: VAProfile::Models::GenderIdentity.build_from(response_body)
        )
      end
    end
  end
end
