# frozen_string_literal: true

module Vet360
  module Models
    class Email < Base
      attribute :created_at, Common::ISO8601Time
      attribute :email_address, String
      attribute :id, Integer
      attribute :source_date, Common::ISO8601Time
      attribute :transaction_id, String
      attribute :updated_at, Common::ISO8601Time

      validates(
        :email_address,
        presence: true,
        format: { with: EVSS::PCIU::EmailAddress::VALID_EMAIL_REGEX },
        length: { maximum: 255, minimum: 6 }
      )

      def to_request()
        {
          bio: {
            emailAddressText: @email_address,
            emailId: @id,
            # emailPermInd: true, # @TODO ??
            originatingSourceSystem: Settings.vet360.cuf_system_name,
            sourceDate: @source_date,
            vet360Id: 1 # current_user.vet360_id # @TODO
          }
        }.to_json
      end

      def self.from_response(body)
        Vet360::Models::Email.new(
          created_at: body['create_date'],
          email_address: body['email_address_text'],
          id: body['email_id'],
          source_date: body['source_date'],
          transaction_id: body['tx_audit_id'],
          updated_at: body['update_date']
        )
      end
    end
  end
end
