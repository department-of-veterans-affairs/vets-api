# frozen_string_literal: true

require 'evss/pciu/base_model'

module EVSS
  module PCIU
    ##
    # Model for PCIU email addresses
    #
    # @!attribute email
    #   @return [String] Email address between 6-255 characters containing an @-sign and a period to indicate a TLD
    #
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
