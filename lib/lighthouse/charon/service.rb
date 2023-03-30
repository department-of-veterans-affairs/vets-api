# frozen_string_literal: true

require 'lighthouse/charon/configuration'
require 'lighthouse/charon/response'

module Charon
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    configuration Charon::Configuration

    def call(action, url, duz, site)
      connection.send(action) do |req|
        req.url url
        req.headers['Content-Type'] = 'application/json'
        req.headers['Accept'] = 'application/json'
        req.params = { duz:, site: }
      end
    end

    def call_charon(duz, site)
      Charon::Response.new call('get', Settings.oidc.charon.endpoint, duz, site)
    end
  end
end
