# frozen_string_literal: true

module SignIn
  module Constants
    module Auth
      BROKER_CODE = 'sis'
      CODE_CHALLENGE_METHOD = 'S256'
      JWT_ENCODE_ALGORITHM = 'RS256'
      GRANT_TYPE = 'authorization_code'
      CSP_TYPES = [IDME = 'idme', LOGINGOV = 'logingov', DSLOGON = 'dslogon', MHV = 'mhv'].freeze
      CLIENT_STATE_MINIMUM_LENGTH = 22
      ACCESS_TOKEN_COOKIE_NAME = 'vagov_access_token'
      REFRESH_TOKEN_COOKIE_NAME = 'vagov_refresh_token'
      ANTI_CSRF_COOKIE_NAME = 'vagov_anti_csrf_token'
      INFO_COOKIE_NAME = 'vagov_info_token'
      REFRESH_ROUTE_PATH = '/v0/sign_in/refresh'
      ACR_VALUES = [LOA1 = 'loa1', LOA3 = 'loa3', IAL1 = 'ial1', IAL2 = 'ial2', MIN = 'min'].freeze
      ACCESS_DENIED = 'access_denied'
    end
  end
end
