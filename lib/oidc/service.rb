# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'oidc/configuration'
require 'oidc/response'
require 'common/exceptions/token_validation_error'

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
      rescue
        raise Common::Exceptions::OpenIdServiceError.new(detail: 'Issuer not found', code: 404, status: 404)
      end
    end

    def oidc_jwks_keys(iss)
      url = metadata(iss).body['jwks_uri']
      if url.nil?
        raise Common::Exceptions::OpenIdServiceError.new(detail: 'Issuer keys not found', code: 404, status: 404)
      end

      with_monitoring do
        call_no_token('get', url)
      rescue
        raise Common::Exceptions::OpenIdServiceError.new(detail: 'JWKS not found', code: 404, status: 404)
      end
    end

    def get_metadata_endpoint(iss)
      metadata_endpoint = Settings.oidc.issuers.find { |s| iss.downcase.start_with? s['prefix'].downcase }
      unless valid_metadata_config?(metadata_endpoint)
        raise Common::Exceptions::OpenIdServiceError.new(detail: 'Unauthorized Issuer', code: 401, status: 401)
      end

      proxied_iss = iss.gsub(metadata_endpoint['prefix'], metadata_endpoint['proxy'])
      proxied_iss + metadata_endpoint['metadata']
    end

    private

    def valid_metadata_config?(metadata_endpoint)
      !metadata_endpoint.nil? && !metadata_endpoint['prefix'].nil? &&
        !metadata_endpoint['metadata'].nil? && !metadata_endpoint['proxy'].nil?
    end
  end
end
