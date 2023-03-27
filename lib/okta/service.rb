# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'
require_relative 'response'

module Okta
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.okta'
    API_BASE_PATH = '/api/v1'
    USER_API_BASE_PATH = "#{API_BASE_PATH}/users".freeze
    APP_API_BASE_PATH = "#{API_BASE_PATH}/apps".freeze
    AUTH_SERVER_API_BASE_PATH = "#{API_BASE_PATH}/authorizationServers".freeze

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

    def auth_server(auth_server_id)
      with_monitoring do
        get_url_with_token("#{AUTH_SERVER_API_BASE_PATH}/#{auth_server_id}")
      end
    end

    def auth_servers
      with_monitoring do
        get_url_with_token(AUTH_SERVER_API_BASE_PATH)
      end
    end

    def get_server_scopes(server_id)
      with_monitoring do
        get_url_with_token("#{AUTH_SERVER_API_BASE_PATH}/#{server_id}/scopes")
      end
    end

    def user(user_id)
      with_monitoring do
        get_url_with_token("#{USER_API_BASE_PATH}/#{user_id}")
      end
    end

    def user_search_by_icn(icn)
      with_monitoring do
        get_url_with_token("#{USER_API_BASE_PATH}?search=profile.lighthouseId+eq+%22#{icn}%22")
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

    def system_logs(event, time)
      with_monitoring do
        get_url_with_token("#{API_BASE_PATH}/logs?filter=eventType+eq+%22#{event}%22&since=#{time}")
      end
    end

    def metadata(iss)
      proxied_iss = iss.gsub(Settings.oidc.issuer_prefix, "#{Settings.oidc.base_api_url}oauth2")
      with_monitoring do
        get_url_no_token("#{proxied_iss}/.well-known/openid-configuration")
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
