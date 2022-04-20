# frozen_string_literal: true

require_relative 'base'
require 'common/models/attribute_types/iso8601_time'
require 'va_profile/concerns/defaultable'

module VAProfile
  module Models
    class PreferredName < Base
      include VAProfile::Concerns::Defaultable

      attribute :text, String
      attribute :source_date, Common::ISO8601Time

      # Converts a decoded JSON response from VAProfile to an instance of the PreferredName model
      # @param body [Hash] the decoded response body from VAProfile
      # @return [VAProfile::Models::PreferredName] the model built from the response body
      def self.build_from(body)
        return nil unless body

        VAProfile::Models::PreferredName.new(
          text: body['preferred_name']
        )
      end
    end
  end
end
