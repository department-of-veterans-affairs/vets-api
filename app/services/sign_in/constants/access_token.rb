# frozen_string_literal: true

module SignIn
  module Constants
    module AccessToken
      VALIDITY_LENGTH_MINUTES = 5
      JWT_ENCODE_ALROGITHM = 'RS256'

      VERSION_LIST = [
        CURRENT_VERSION = 'V0'
      ].freeze

      ISSUER = 'va.gov sign in'

      MOBILE_CLIENT_ID = 'vamobile'
      MOBILE_AUDIENCE = 'vamobile'
    end
  end
end
