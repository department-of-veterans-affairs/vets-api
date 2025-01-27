# frozen_string_literal: true

require_relative 'base'
require 'common/models/attribute_types/iso8601_time'
require 'va_profile/concerns/defaultable'
require 'va_profile/concerns/expirable'

module VAProfile
  module Models
    class Email < Base
      include VAProfile::Concerns::Defaultable
      include VAProfile::Concerns::Expirable
      VALID_EMAIL_REGEX = /.+@.+\..+/i

      attribute :created_at, Common::ISO8601Time
      attribute :email_address, String
      attribute :effective_end_date, Common::ISO8601Time
      attribute :effective_start_date, Common::ISO8601Time
      attribute :id, Integer
      attribute :source_date, Common::ISO8601Time
      attribute :source_system_user, String
      attribute :transaction_id, String
      attribute :updated_at, Common::ISO8601Time
      attribute :vet360_id, String
      attribute :va_profile_id, String

      validates(
        :email_address,
        presence: true,
        format: { with: VALID_EMAIL_REGEX },
        length: { maximum: 255, minimum: 6 }
      )

      # Converts an instance of the Email model to a JSON encoded string suitable for use in
      # the body of a request to VAProfile
      # @return [String] JSON-encoded string suitable for requests to VAProfile
      def in_json
        {
          bio: {
            emailAddressText: @email_address,
            emailId: @id,
            originatingSourceSystem: SOURCE_SYSTEM,
            sourceSystemUser: @source_system_user,
            sourceDate: @source_date,
            vet360Id: @vet360_id || @vaProfileId,
            effectiveStartDate: @effective_start_date,
            effectiveEndDate: @effective_end_date
          }
        }.to_json
      end

      # Contact Information V2 requests do not need the vet360Id
      # in_json_v2 will replace in_json when Contact Information V1 Service has depreciated
      def in_json_v2
        {
          bio: {
            emailAddressText: @email_address,
            emailId: @id,
            originatingSourceSystem: SOURCE_SYSTEM,
            sourceSystemUser: @source_system_user,
            sourceDate: @source_date,
            effectiveStartDate: @effective_start_date,
            effectiveEndDate: @effective_end_date
          }
        }.to_json
      end

      # Converts a decoded JSON response from VAProfile to an instance of the Email model
      # @param body [Hash] the decoded response body from VAProfile
      # @return [VAProfile::Models::Email] the model built from the response body
      def self.build_from(body)
        VAProfile::Models::Email.new(
          created_at: body['create_date'],
          email_address: body['email_address_text'],
          effective_end_date: body['effective_end_date'],
          effective_start_date: body['effective_start_date'],
          id: body['email_id'],
          source_date: body['source_date'],
          transaction_id: body['tx_audit_id'],
          updated_at: body['update_date'],
          vet360_id: body['vet360_id'] || body['va_profile_id'],
          va_profile_id: body['va_profile_id'] || body['vet360_id']
        )
      end
    end
  end
end
