# frozen_string_literal: true

require 'common/client/base'

module Okta
  class Service < Common::Client::Base
    include Common::Client::Monitoring

    STATSD_KEY_PREFIX = 'api.okta'

    configuration Okta::Configuration

    def get_url_with_token(url)
      connection.get do |req|
        req.url url
        req.headers['Content-Type'] = 'application/json'
        req.headers['Accept'] = 'application/json'
        req.headers['Authorization'] = "SSWS #{Settings.oidc.base_api_token}"
      end
    end
  end
end
