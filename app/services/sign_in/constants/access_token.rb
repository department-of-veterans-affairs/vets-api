# frozen_string_literal: true

module SignIn
  module Constants
    module AccessToken
      VALIDITY_LENGTHS = [VALIDITY_LENGTH_SHORT_MINUTES = 5.minutes, VALIDITY_LENGTH_LONG_MINUTES = 30.minutes].freeze
      JWT_ENCODE_ALGORITHM = 'RS256'

      VERSION_LIST = [
        CURRENT_VERSION = 'V0'
      ].freeze

      ISSUER = 'va.gov sign in'
      USER_ATTRIBUTES = %w[first_name last_name email].freeze
    end
  end
end
