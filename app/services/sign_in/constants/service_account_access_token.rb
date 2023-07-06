# frozen_string_literal: true

module SignIn
  module Constants
    module ServiceAccountAccessToken
      VALIDITY_LENGTH_SHORT_MINUTES = 5.minutes
      JWT_ENCODE_ALGORITHM = 'RS256'

      VERSION_LIST = [
        CURRENT_VERSION = 'V0'
      ].freeze

      ISSUER = 'va_sign_in_service'
    end
  end
end
