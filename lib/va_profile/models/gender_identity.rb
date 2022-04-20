# frozen_string_literal: true

require_relative 'base'
require 'common/models/attribute_types/iso8601_time'
require 'va_profile/concerns/defaultable'

module VAProfile
  module Models
    class GenderIdentity < Base
      include VAProfile::Concerns::Defaultable

      OPTIONS = {
        'M' => 'Male',
        'F' => 'Female',
        'TM' => 'Transgender Man',
        'TF' => 'Transgender Female',
        'B' => 'Non-Binary',
        'N' => 'Does not wish to disclose',
        'O' => 'Other'
      }.freeze

      attribute :code, String
      attribute :name, String
      attribute :source_date, Common::ISO8601Time

      skip_callback :validate, :past_date?
      validates :code, presence: true
      validates :name, presence: true
      validates_inclusion_of :code, in: OPTIONS, message: 'invalid code', if: -> { @code.present? }
      validates_inclusion_of :name, in: OPTIONS.invert, message: 'invalid name', if: -> { @name.present? }
      validate :gender_identity_options

      # Converts an instance of the GenderIdentity model to a JSON encoded string suitable for
      # use in the body of a request to VAProfile
      #
      # @return [String] JSON-encoded string suitable for requests to VAProfile
      def in_json
        {
          bio: {
            genderIdentity: [
              {
                genderIdentityCode: @code,
                genderIdentityName: @name
              }
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

      private

      def gender_identity_options
        return if errors.any? # don't bother if code or name in already invalid

        errors.add(:base, 'invalid code/name combination') if @name != OPTIONS[@code]
      end
    end
  end
end
