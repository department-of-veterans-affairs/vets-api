# frozen_string_literal: true

module SignIn
  module Constants
    module Auth
      CODE_CHALLENGE_METHOD = 'S256'
      GRANT_TYPE = 'authorization_code'
      REDIRECT_URLS = %w[idme logingov dslogon mhv].freeze
      CLIENT_STATE_MINIMUM_LENGTH = 22
      ACCESS_TOKEN_COOKIE_NAME = 'vagov_access_token'
      REFRESH_TOKEN_COOKIE_NAME = 'vagov_refresh_token'
      ANTI_CSRF_COOKIE_NAME = 'vagov_anti_csrf_token'
      REFRESH_ROUTE_PATH = '/v0/sign_in/refresh'
    end
  end
end
