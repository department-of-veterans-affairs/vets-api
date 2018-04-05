# frozen_string_literal: true

module Vet360
  module Models
    class Email < Base
      attribute :email_address, String

      validates(
        :email_address,
        presence: true,
        format: { with: EVSS::PCIU::EmailAddress::VALID_EMAIL_REGEX },
        length: { maximum: 255, minimum: 6 }
      )
    end
  end
end
