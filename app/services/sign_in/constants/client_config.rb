# frozen_string_literal: true

module SignIn
  module Constants
    module ClientConfig
      CLIENT_IDS = [MOBILE_CLIENT = 'mobile', MOBILE_TEST_CLIENT = 'mobile_test', WEB_CLIENT = 'web'].freeze
      AUDIENCE = [MOBILE_AUDIENCE = 'vamobile', MOBILE_TEST_AUDIENCE = 'vamobile', WEB_AUDIENCE = 'va.gov'].freeze
      COOKIE_AUTH = [WEB_CLIENT].freeze
      API_AUTH = [MOBILE_CLIENT, MOBILE_TEST_CLIENT].freeze
      ANTI_CSRF_ENABLED = [WEB_CLIENT].freeze
      SHORT_TOKEN_EXPIRATION = [WEB_CLIENT, MOBILE_TEST_CLIENT].freeze
      LONG_TOKEN_EXPIRATION = [MOBILE_CLIENT].freeze
    end
  end
end
