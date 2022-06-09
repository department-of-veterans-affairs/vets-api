# frozen_string_literal: true

module SignIn
  module Constants
    module ClientConfig
      CLIENT_IDS = %w[mobile web].freeze
      COOKIE_AUTH = %w[web].freeze
      API_AUTH = %w[mobile].freeze
      ANTI_CSRF_ENABLED = %w[web].freeze
    end
  end
end
