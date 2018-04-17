# frozen_string_literal: true

module Vet360
  module Models
    class Email < Base
      attribute :created_at, Common::ISO8601Time
      attribute :email_address, String
      attribute :effective_end_date, Common::ISO8601Time
      attribute :effective_start_date, Common::ISO8601Time
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

      def to_request(vet360_id)
        {
          bio: {
            emailAddressText: @email_address,
            emailId: @id,
            # emailPermInd: true, # @TODO ??
            originatingSourceSystem: Settings.vet360.cuf_system_name,
            sourceDate: @source_date,
            vet360Id: vet360_id
          }
        }.to_json
      end

      def self.from_response(body)
        Vet360::Models::Email.new(
          created_at: body['create_date'],
          email_address: body['email_address_text'],
          effective_end_date: body['effective_end_date'],
          effective_start_date: body['effective_start_date'],
          id: body['email_id'],
          source_date: body['source_date'],
          transaction_id: body['tx_audit_id'],
          updated_at: body['update_date']
        )
      end
    end
  end
end
