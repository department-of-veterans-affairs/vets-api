# frozen_string_literal: true

require 'charon/configuration'
require 'charon/response'

module CHARON
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    configuration CHARON::Configuration

    def call(action, url, duz, site)
      connection.send(action) do |req|
        req.url url
        req.headers['Content-Type'] = 'application/json'
        req.headers['Accept'] = 'application/json'
        req.params = { duz: duz, site: site }
      end
    end

    def call_charon(duz, site)
      CHARON::Response.new call('get', Settings.oidc.charon.endpoint, duz, site)
    end

  end
end
