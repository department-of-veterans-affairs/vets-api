# frozen_string_literal: true

module Vet360
  module Models
    class Email < Base
      attribute :created_at, Common::ISO8601Time
      attribute :effective_end_date, Common::ISO8601Time
      attribute :effective_start_date, Common::ISO8601Time
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
    end
  end
end
