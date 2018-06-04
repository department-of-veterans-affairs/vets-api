# frozen_string_literal: true

module Vet360
  module Models
    class Email < Base
      include Vet360::Concerns::Defaultable

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

      validates(
        :email_address,
        presence: true,
        format: { with: EVSS::PCIU::EmailAddress::VALID_EMAIL_REGEX },
        length: { maximum: 255, minimum: 6 }
      )

      # Converts an instance of the Email model to a JSON encoded string suitable for use in
      # the body of a request to Vet360
      # @return [String] JSON-encoded string suitable for requests to Vet360
      def in_json
        {
          bio: {
            emailAddressText: @email_address,
            emailId: @id,
            # emailPermInd: true, # @TODO ??
            originatingSourceSystem: SOURCE_SYSTEM,
            sourceSystemUser: @source_system_user,
            sourceDate: @source_date,
            vet360Id: @vet360_id,
            effectiveStartDate: @effective_start_date,
            effectiveEndDate: @effective_end_date
          }
        }.to_json
      end

      # Converts a decoded JSON response from Vet360 to an instance of the Email model
      # @param body [Hash] the decoded response body from Vet360
      # @return [Vet360::Models::Email] the model built from the response body
      def self.build_from(body)
        Vet360::Models::Email.new(
          created_at: body['create_date'],
          email_address: body['email_address_text'],
          effective_end_date: body['effective_end_date'],
          effective_start_date: body['effective_start_date'],
          id: body['email_id'],
          source_date: body['source_date'],
          transaction_id: body['tx_audit_id'],
          updated_at: body['update_date'],
          vet360_id: body['vet360_id']
        )
      end
    end
  end
end
