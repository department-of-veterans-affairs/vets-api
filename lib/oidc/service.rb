# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'oidc/configuration'
require 'oidc/response'
module OIDC
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    configuration OIDC::Configuration

    STATSD_KEY_PREFIX = 'oidc'

    def call_no_token(action, url)
      connection.send(action) do |req|
        req.url url
        req.headers['Content-Type'] = 'application/json'
        req.headers['Accept'] = 'application/json'
      end
    end

    def metadata(iss)
      metadata_endpoint = get_metadata_endpoint(iss)
      with_monitoring do
        OIDC::Response.new call_no_token('get', metadata_endpoint)
      end
    end

    def oidc_jwks_keys(iss)
      url = metadata(iss).body['jwks_uri']
      with_monitoring do
        call_no_token('get', url)
      end
    end

    def get_metadata_endpoint(iss)
      metadata_endpoint = Settings.oidc.issuers.find { |s| iss.downcase.include? s['prefix'].downcase }
      proxied_iss = iss.gsub(metadata_endpoint['prefix'], metadata_endpoint['proxy'])
      proxied_iss + metadata_endpoint['metadata']
    end
  end
end
