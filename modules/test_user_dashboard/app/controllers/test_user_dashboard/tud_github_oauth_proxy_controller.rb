# frozen_string_literal: true

require 'sentry_logging'
require 'faraday'
require 'net/http'

module TestUserDashboard
  class TudGithubOAuthProxyController < ApplicationController
    def index
      code = params[:code]
      token = github_oauth_access_token_request(code:)
      render json: token
    rescue => e
      log_exception_to_sentry(e, nil, nil, 'warn')
      render nothing: true, status: :bad_request
    end

    private

    def github_oauth_access_token_request(code:)
      url = 'https://github.com/login/oauth/access_token'
      body = {
        client_id: Settings.test_user_dashboard.github_oauth.client_id,
        client_secret: Settings.test_user_dashboard.github_oauth.client_secret,
        code:
      }.to_json

      response = Faraday.post(url, body, 'Content-Type': 'application/json')

      if response.success?
        response.body.split('&').each do |string|
          if string.start_with?('access_token=')
            array = string.split('=')
            return { array[0] => array[1] }
          end
        end
      else
        raise Common::Exceptions::ServiceError('TestUserDashboard GitHub OAuth token generation failed.')
      end
    end
  end
end
