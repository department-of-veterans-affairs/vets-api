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
    end
  end
end
