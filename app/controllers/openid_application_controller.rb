# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'rest-client'
require 'saml/settings_service'
require 'sentry_logging'
require 'oidc/key_service'
require 'okta/user_profile'
require 'okta/service'
require 'jwt'

class OpenidApplicationController < ApplicationController
  include OAuthConcerns
  skip_before_action :verify_authenticity_token
  skip_after_action :set_csrf_header
  before_action :authenticate
  TOKEN_REGEX = /Bearer /.freeze

  private

  def token_from_request
    auth_request = request.authorization.to_s
    return unless auth_request[TOKEN_REGEX]

    token_string = auth_request.sub(TOKEN_REGEX, '').gsub(/^"|"$/, '')

    if jwt?(token_string)
      Token.new(token_string, fetch_aud)
    else
      # Future block for opaque tokens
      raise error_klass('Invalid token.')
    end
  end

  def jwt?(token_string)
    JWT.decode(token_string, nil, false, algorithm: 'RS256')
    true
  rescue JWT::DecodeError
    false
  end

  def error_klass(error_detail_string)
    # Errors from the jwt gem (and other dependencies) are reraised with
    # this class so we can exclude them from Sentry without needing to know
    # all the classes used by our dependencies.
    Common::Exceptions::TokenValidationError.new(detail: error_detail_string)
  end

  def token
    @token ||= token_from_request
  end

  def fetch_smart_launch_context
    response = RestClient.get(Settings.oidc.smart_launch_url,
                              { Authorization: 'Bearer ' + token.token_string })
    unless response.nil? || response.code != 200
      json_response = JSON.parse(response.body)
      json_response['launch']
    end
  rescue => e
    log_message_to_sentry('Error retrieving smart launch context for OIDC token: ' + e.message, :error)
    nil
  end

  attr_reader :current_user, :session, :scopes
end
