# frozen_string_literal: true

module EVSS
  module PCIU
    class EmailAddress < BaseModel
      VALID_EMAIL_REGEX = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i

      attribute :email, String

      validates :email, presence: true
      validates_format_of :email, with: VALID_EMAIL_REGEX
    end
  end
end
