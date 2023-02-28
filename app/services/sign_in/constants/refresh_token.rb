# frozen_string_literal: true

module SignIn
  module Constants
    module RefreshToken
      ENCRYPTED_ARRAY = [
        ENCRYPTED_POSITION = 0,
        NONCE_POSITION = 1,
        VERSION_POSITION = 2
      ].freeze

      VERSION_LIST = [
        CURRENT_VERSION = 'V0'
      ].freeze

      VALIDITY_LENGTHS = [VALIDITY_LENGTH_SHORT_MINUTES = 30.minutes, VALIDITY_LENGTH_LONG_DAYS = 45.days].freeze

      SESSION_MAX_VALIDITY_LENGTH_DAYS = 45.days
    end
  end
end
