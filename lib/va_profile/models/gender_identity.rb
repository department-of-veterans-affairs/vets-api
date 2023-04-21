# frozen_string_literal: true

require_relative 'base'
require 'common/models/attribute_types/iso8601_time'
require 'va_profile/concerns/defaultable'

module VAProfile
  module Models
    class GenderIdentity < Base
      include VAProfile::Concerns::Defaultable

      CODES = %w[M F TM TF B N O].freeze
      OPTIONS = {
        'M' => 'Man',
        'B' => 'Non-binary',
        'TM' => 'Transgender man',
        'TF' => 'Transgender woman',
        'F' => 'Woman',
        'N' => 'Prefer not to answer',
        'O' => 'A gender not listed here'
      }.freeze

      attribute :code, String
      attribute :name, String
      attribute :source_system_user, String
      attribute :source_date, Common::ISO8601Time

      validates :code, presence: true
      validates_inclusion_of :code, in: OPTIONS, message: 'invalid code', if: -> { @code.present? }

      def code=(val)
        @code = val
        @name = OPTIONS[@code]
      end

      # Converts an instance of the GenderIdentity model to a JSON encoded string suitable for
      # use in the body of a request to VAProfile
      #
      # @return [String] JSON-encoded string suitable for requests to VAProfile
      def in_json
        {
          bio: {
            genderIdentity: [
              genderIdentityCode: @code
            ],
            sourceDate: @source_date,
            originatingSourceSystem: SOURCE_SYSTEM,
            sourceSystemUser: @source_system_user
          }
        }.to_json
      end

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
