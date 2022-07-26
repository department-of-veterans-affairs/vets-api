# frozen_string_literal: true

module SignIn
  module Constants
    module ClientConfig
      MOBILE_CLIENT = 'mobile'
      MOBILE_TEST_CLIENT = 'mobile_test'
      WEB_CLIENT = 'web'
      CLIENT_IDS = [MOBILE_CLIENT, MOBILE_TEST_CLIENT, WEB_CLIENT].freeze
      COOKIE_AUTH = [WEB_CLIENT].freeze
      API_AUTH = [MOBILE_CLIENT, MOBILE_TEST_CLIENT].freeze
      ANTI_CSRF_ENABLED = [WEB_CLIENT].freeze
    end
  end
end
