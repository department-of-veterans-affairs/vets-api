# frozen_string_literal: true

module SignIn
  module Constants
    module Auth
      BROKER_CODE = 'sis'
      CODE_CHALLENGE_METHOD = 'S256'
      JWT_ENCODE_ALGORITHM = 'RS256'
      GRANT_TYPE = 'authorization_code'
      REDIRECT_URLS = %w[idme logingov dslogon mhv].freeze
      CLIENT_STATE_MINIMUM_LENGTH = 22
      ACCESS_TOKEN_COOKIE_NAME = 'vagov_access_token'
      REFRESH_TOKEN_COOKIE_NAME = 'vagov_refresh_token'
      ANTI_CSRF_COOKIE_NAME = 'vagov_anti_csrf_token'
      INFO_COOKIE_NAME = 'vagov_info_token'
      REFRESH_ROUTE_PATH = '/v0/sign_in/refresh'
      ACR_VALUES = %w[loa1 loa3 ial1 ial2 min].freeze
    end
  end
end
