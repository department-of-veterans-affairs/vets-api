# frozen_string_literal: true

module SignIn
  module Constants
    module Auth
      ACCESS_TOKEN_COOKIE_NAME = 'vagov_access_token'
      ACCESS_DENIED = 'access_denied'
      ACR_VALUES = [LOA1 = 'loa1',
                    LOA3 = 'loa3',
                    IAL1 = 'ial1',
                    IAL2 = 'ial2',
                    IAL2_REQUIRED  = 'urn:acr.va.gov:verified-facial-match-required',
                    IAL2_PREFERRED = 'urn:acr.va.gov:verified-facial-match-preferred',
                    MIN = 'min'].freeze
      ACR_TRANSLATIONS = [IDME_LOA1 = 'http://idmanagement.gov/ns/assurance/loa/1/vets',
                          IDME_LOA3 = 'http://idmanagement.gov/ns/assurance/loa/3',
                          IDME_LOA3_FORCE = 'http://idmanagement.gov/ns/assurance/loa/3_force',
                          IDME_IAL2 = 'http://idmanagement.gov/ns/assurance/ial/2/aal/2',
                          IDME_CLASSIC_LOA3 = 'classic_loa3',
                          IDME_DSLOGON_LOA1 = 'dslogon',
                          IDME_DSLOGON_LOA3 = 'dslogon_loa3',
                          IDME_MHV_LOA1 = 'myhealthevet',
                          IDME_MHV_LOA3 = 'myhealthevet_loa3',
                          IDME_COMPARISON_MINIMUM = 'comparison:minimum',
                          MHV_PREMIUM_VERIFIED = %w[Premium].freeze,
                          LOGIN_GOV_IAL0 = 'http://idmanagement.gov/ns/assurance/ial/0',
                          LOGIN_GOV_IAL1 = 'http://idmanagement.gov/ns/assurance/ial/1',
                          LOGIN_GOV_IAL2 = 'http://idmanagement.gov/ns/assurance/ial/2',
                          LOGIN_GOV_IAL2_REQUIRED = 'urn:acr.login.gov:verified-facial-match-required',
                          LOGIN_GOV_IAL2_PREFERRED = 'urn:acr.login.gov:verified-facial-match-preferred'].freeze
      ANTI_CSRF_COOKIE_NAME = 'vagov_anti_csrf_token'
      AUTHENTICATION_TYPES = [COOKIE = 'cookie', API = 'api', MOCK = 'mock'].freeze
      BROKER_CODE = 'sis'
      CLIENT_STATE_MINIMUM_LENGTH = 22
      CODE_CHALLENGE_METHOD = 'S256'
      CSP_TYPES = [IDME = 'idme', LOGINGOV = 'logingov', DSLOGON = 'dslogon', MHV = 'mhv'].freeze
      OPERATION_TYPES = [SIGN_UP = 'sign_up',
                         AUTHORIZE = 'authorize',
                         AUTHORIZE_SSO = 'authorize_sso',
                         INTERSTITIAL_VERIFY = 'interstitial_verify',
                         INTERSTITIAL_SIGNUP = 'interstitial_signup',
                         VERIFY_CTA_AUTHENTICATED = 'verify_cta_authenticated',
                         VERIFY_PAGE_AUTHENTICATED = 'verify_page_authenticated',
                         VERIFY_PAGE_UNAUTHENTICATED = 'verify_page_unauthenticated'].freeze
      GRANT_TYPES = [AUTH_CODE_GRANT = 'authorization_code',
                     JWT_BEARER_GRANT = Urn::JWT_BEARER_GRANT_TYPE,
                     TOKEN_EXCHANGE_GRANT = Urn::TOKEN_EXCHANGE_GRANT_TYPE].freeze
      ENFORCED_TERMS = [VA_TERMS = 'VA'].freeze
      ASSERTION_ENCODE_ALGORITHM = 'RS256'
      IAL = [IAL_ONE = 1, IAL_TWO = 2].freeze
      INFO_COOKIE_NAME = 'vagov_info_token'
      JWT_ENCODE_ALGORITHM = 'RS256'
      LOA = [LOA_ONE = 1, LOA_THREE = 3].freeze
      REFRESH_ROUTE_PATH = '/v0/sign_in/refresh'
      REFRESH_TOKEN_COOKIE_NAME = 'vagov_refresh_token'
      SERVICE_ACCOUNT_ACCESS_TOKEN_COOKIE_NAME = 'service_account_access_token'
      SCOPES = [DEVICE_SSO = 'device_sso'].freeze
      TOKEN_ROUTE_PATH = '/v0/sign_in/token'
    end
  end
end
