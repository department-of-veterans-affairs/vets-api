# frozen_string_literal: true

require_relative 'base'
require 'common/models/attribute_types/iso8601_time'
require 'va_profile/concerns/defaultable'

module VAProfile
  module Models
    class GenderIdentity < Base
      include VAProfile::Concerns::Defaultable

      attribute :code, String
      attribute :name, String
      attribute :source_date, Common::ISO8601Time

      # Converts a decoded JSON response from VAProfile to an instance of the GenderIdentity model
      # @param body [Hash] the decoded response body from VAProfile
      # @return [VAProfile::Models::GenderIdentity] the model built from the response body
      def self.build_from(body)
        return nil unless body

        VAProfile::Models::GenderIdentity.new(
          code: body['gender_identity_code'],
          name: body['gender_identity_name']
        )
      end
    end
  end
end
