# frozen_string_literal: true

module SignIn
  module Constants
    module ServiceAccountAccessToken
      ISSUER = 'va.gov sign in'
      JWT_ENCODE_ALGORITHM = 'RS256'
      USER_ATTRIBUTES = %w[icn type credential_id participant_id].freeze
      VALIDITY_LENGTHS = [VALIDITY_LENGTH_SHORT_MINUTES = 5.minutes, VALIDITY_LENGTH_LONG_MINUTES = 30.minutes].freeze
      VERSION_LIST = [
        CURRENT_VERSION = 'V0'
      ].freeze
    end
  end
end
