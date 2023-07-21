# frozen_string_literal: true

module SignIn
  module Constants
    module Auth
      ACCESS_TOKEN_COOKIE_NAME = 'vagov_access_token'
      ACCESS_DENIED = 'access_denied'
      ACR_VALUES = [LOA1 = 'loa1', LOA3 = 'loa3', IAL1 = 'ial1', IAL2 = 'ial2',
                    MIN = 'min'].freeze
      ACR_TRANSLATIONS = [IDME_LOA1 = 'http://idmanagement.gov/ns/assurance/loa/1/vets',
                          IDME_LOA3 = 'http://idmanagement.gov/ns/assurance/loa/3',
                          IDME_LOA3_FORCE = 'http://idmanagement.gov/ns/assurance/loa/3_force',
                          IDME_CLASSIC_LOA3 = 'classic_loa3',
                          IDME_DSLOGON_LOA1 = 'dslogon',
                          IDME_DSLOGON_LOA3 = 'dslogon_loa3',
                          IDME_MHV_LOA1 = 'myhealthevet',
                          IDME_MHV_LOA3 = 'myhealthevet_loa3',
                          MHV_PREMIUM_VERIFIED = %w[Premium].freeze,
                          DSLOGON_PREMIUM_VERIFIED = [DSLOGON_ASSURANCE_TWO = '2',
                                                      DSLOGON_ASSURANCE_THREE = '3'].freeze,
                          LOGIN_GOV_IAL1 = 'http://idmanagement.gov/ns/assurance/ial/1',
                          LOGIN_GOV_IAL2 = 'http://idmanagement.gov/ns/assurance/ial/2'].freeze
      ANTI_CSRF_COOKIE_NAME = 'vagov_anti_csrf_token'
      AUTHENTICATION_TYPES = [COOKIE = 'cookie', API = 'api', MOCK = 'mock'].freeze
      BROKER_CODE = 'sis'
      CLIENT_STATE_MINIMUM_LENGTH = 22
      CODE_CHALLENGE_METHOD = 'S256'
      CSP_TYPES = [IDME = 'idme', LOGINGOV = 'logingov', DSLOGON = 'dslogon', MHV = 'mhv'].freeze
      GRANT_TYPES = [AUTH_CODE = 'authorization_code',
                     JWT_BEARER = 'urn:ietf:params:oauth:grant-type:jwt-bearer'].freeze
      CLIENT_ASSERTION_TYPE = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
      ASSERTION_ENCODE_ALGORITHM = 'RS256'
      IAL = [IAL_ONE = 1, IAL_TWO = 2].freeze
      INFO_COOKIE_NAME = 'vagov_info_token'
      JWT_ENCODE_ALGORITHM = 'RS256'
      LOA = [LOA_ONE = 1, LOA_THREE = 3].freeze
      REFRESH_ROUTE_PATH = '/v0/sign_in/refresh'
      REFRESH_TOKEN_COOKIE_NAME = 'vagov_refresh_token'
      SERVICE_ACCOUNT_ACCESS_TOKEN_COOKIE_NAME = 'service_account_access_token'
      TOKEN_ROUTE_PATH = '/v0/sign_in/token'
    end
  end
end
