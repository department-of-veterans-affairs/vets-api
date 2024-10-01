# frozen_string_literal: true

require 'vets/model'

module EVSS
  module PCIU
    class EmailAddress < Vets::Model
      ##
      # Model for PCIU email addresses
      #
      # @!attribute email
      #   @return [String] Email address between 6-255 characters containing an @-sign and a period to indicate a TLD
      #
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
