# frozen_string_literal: true

require_relative 'base'
require 'common/models/attribute_types/iso8601_time'
require 'va_profile/concerns/defaultable'

module VAProfile
  module Models
    class PreferredName < Base
      include VAProfile::Concerns::Defaultable

      attribute :text, String
      attribute :source_system_user, String
      attribute :source_date, Common::ISO8601Time

      validates :text, presence: true
      validates :text, length: { maximum: 25 }
      validates :text, format: { without: /\s/, message: "must not contain spaces" }
      validates :text, format: { with: /\A[a-zA-ZÀ-ÖØ-öø-ÿ\-áéíóúäëïöüâêîôûãñõ]+\z/,
        message: 'must only contain alpha, -, acute, grave, diaresis, circumflex, tilde' }
      
      # must only contain alpha, -, acute, grave, diaresis, cirumflex, tilde (case insensitive)
      # validates :text, preferred_name: true
      # validates :text, format: { without: /\s/, message: "must not contain spaces" }

      # Converts an instance of the PreferredName model to a JSON encoded string suitable for
      # use in the body of a request to VAProfile
      #
      # @return [String] JSON-encoded string suitable for requests to VAProfile
      #
      def in_json
        {
          bio: {
            preferredName: @text,
            originatingSourceSystem: SOURCE_SYSTEM,
            sourceDate: @source_date,
            sourceSystemUser: @source_system_user
          }
        }.to_json
      end

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
