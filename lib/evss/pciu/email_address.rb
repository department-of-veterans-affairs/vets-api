# frozen_string_literal: true

module EVSS
  module PCIU
    class EmailAddress < BaseModel
      # This regex comes from the `validates_format_of` Rails docs
      #
      # @see https://apidock.com/rails/ActiveModel/Validations/HelperMethods/validates_format_of
      #
      VALID_EMAIL_REGEX = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i

      attribute :email, String

      validates :email, presence: true
      validates_format_of :email, with: VALID_EMAIL_REGEX
    end
  end
end
