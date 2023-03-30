# frozen_string_literal: true

require_relative 'base'
require_relative 'gender_identity'
require_relative 'preferred_name'
require 'common/models/attribute_types/iso8601_time'

module VAProfile
  module Models
    class Demographic < Base
      attribute :id, String
      attribute :type, String
      attribute :gender, String
      attribute :birth_date, String
      attribute :preferred_name, PreferredName
      attribute :gender_identity, GenderIdentity

      # Converts a decoded JSON response from VAProfile to an instance of the Demographic model
      # @param body [Hash] the decoded response body from VAProfile
      # @return [VAProfile::Models::Demographics] the model built from the response body
      def self.build_from(body)
        preferred_name = VAProfile::Models::PreferredName.build_from(body&.dig('preferred_name'))

        # VA Profile API returns collection, but there should only be a single record.
        gender_identity = VAProfile::Models::GenderIdentity.build_from(body&.dig('gender_identity')&.first)

        VAProfile::Models::Demographic.new(
          preferred_name:,
          gender_identity:
        )
      end
    end
  end
end
