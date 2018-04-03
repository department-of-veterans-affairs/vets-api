# frozen_string_literal: true

module EVSS
  module PCIU
    class EmailAddress < BaseModel
      VALID_EMAIL_REGEX = /.+@.+\..+/i

      attribute :email, String

      validates(
        :email,
        presence: true,
        format: { with: VALID_EMAIL_REGEX },
        length: { maximum: 255, minimum: 6 }
      )
    end
  end
end
