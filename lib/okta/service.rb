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

    %i[get post put delete].each do |http_verb|
      define_method("#{http_verb}_url_with_token".to_sym) do |url|
        call_with_token(http_verb, url)
      end
    end

    def app(app_id)
      get_url_with_token("#{APP_API_BASE_PATH}/#{app_id}")
    end

    def user(uid)
      get_url_with_token("#{USER_API_BASE_PATH}/#{uid}")
    end

    def grants(uid)
      get_url_with_token("#{USER_API_BASE_PATH}/#{uid}/grants")
    end

    def delete_grant(uid, grant_id)
      delete_url_with_token("#{USER_API_BASE_PATH}/#{uid}/grants/#{grant_id}")
    end
  end
end
