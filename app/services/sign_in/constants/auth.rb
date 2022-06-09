# frozen_string_literal: true

module SignIn
  module Constants
    module Auth
      CODE_CHALLENGE_METHOD = 'S256'
      GRANT_TYPE = 'authorization_code'
      REDIRECT_URLS = %w[idme logingov dslogon mhv].freeze
      CLIENT_IDS = %w[mobile web].freeze
      CLIENT_STATE_MINIMUM_LENGTH = 22
    end
  end
end
