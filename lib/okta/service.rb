# frozen_string_literal: true

require 'common/client/base'

module Okta
  class Service < Common::Client::Base
    include Common::Client::Monitoring

    STATSD_KEY_PREFIX = 'api.okta'
    API_BASE_PATH = '/api/v1'
    USER_API_BASE_PATH = "#{API_BASE_PATH}/users"
    APP_API_BASE_PATH = "#{API_BASE_PATH}/apps"

    configuration Okta::Configuration

    def call_with_token(action, url)
      connection.send(action) do |req|
        req.url url
        req.headers['Content-Type'] = 'application/json'
        req.headers['Accept'] = 'application/json'
        req.headers['Authorization'] = "SSWS #{Settings.oidc.base_api_token}"
      end
    end

    def app(app_id)
      with_monitoring do
        get_url_with_token("#{APP_API_BASE_PATH}/#{app_id}")
      end
    end

    def user(user_id)
      with_monitoring do
        get_url_with_token("#{USER_API_BASE_PATH}/#{user_id}")
      end
    end

    def grants(user_id)
      with_monitoring do
        get_url_with_token("#{USER_API_BASE_PATH}/#{user_id}/grants")
      end
    end

    def delete_grant(user_id, grant_id)
      with_monitoring do
        delete_url_with_token("#{USER_API_BASE_PATH}/#{user_id}/grants/#{grant_id}")
      end
    end

    def metadata
      with_monitoring do
        get_url_with_token(Settings.oidc.auth_server_metadata_url)
      end
    end

    def oidc_jwks_keys
      url = metadata.body['jwks_uri']
      with_monitoring do
        get_url_with_token(url)
      end
    end

    private

    %i[get post put delete].each do |http_verb|
      define_method("#{http_verb}_url_with_token".to_sym) do |url|
        Okta::Response.new call_with_token(http_verb, url)
      end
    end
  end
end
