# frozen_string_literal: true

module SignIn
  module Constants
    module Auth
      ACCESS_TOKEN_COOKIE_NAME = 'vagov_access_token'
      ACCESS_DENIED = 'access_denied'
      ACR_VALUES = [LOA1 = 'loa1', LOA3 = 'loa3', IAL1 = 'ial1', IAL2 = 'ial2', MIN = 'min'].freeze
      ANTI_CSRF_COOKIE_NAME = 'vagov_anti_csrf_token'
      BROKER_CODE = 'sis'
      CLIENT_STATE_MINIMUM_LENGTH = 22
      CODE_CHALLENGE_METHOD = 'S256'
      CSP_TYPES = [IDME = 'idme', LOGINGOV = 'logingov', DSLOGON = 'dslogon', MHV = 'mhv'].freeze
      CLIENT_IDS = [
        WEB_CLIENT = 'web',
        VA_WEB_CLIENT = 'vaweb',
        MOBILE_CLIENT = 'mobile',
        VA_MOBILE_CLIENT = 'vamobile',
        MOBILE_TEST_CLIENT = 'mobile_test'
      ].freeze
      GRANT_TYPE = 'authorization_code'
      INFO_COOKIE_NAME = 'vagov_info_token'
      JWT_ENCODE_ALGORITHM = 'RS256'
      REFRESH_ROUTE_PATH = '/v0/sign_in/refresh'
      REFRESH_TOKEN_COOKIE_NAME = 'vagov_refresh_token'
    end
  end
end
