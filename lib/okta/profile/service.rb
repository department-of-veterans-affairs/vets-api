# frozen_string_literal: true

require 'okta/service'

module Okta
  module Profile
    class Service < Okta::Service
      STATSD_KEY_PREFIX = 'api.okta.profile'

      configuration Okta::Profile::Configuration

      def get_with_token(uid)
        connection.get do |req|
          req.url uid
          req.headers['Content-Type'] = 'application/json'
          req.headers['Accept'] = 'application/json'
          req.headers['Authorization'] = "SSWS #{Settings.oidc.profile_api_token}"
        end
      end
    end
  end
end
