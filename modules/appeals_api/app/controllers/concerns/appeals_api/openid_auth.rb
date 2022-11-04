# frozen_string_literal: true

require 'appeals_api/token_validation_client'

module AppealsApi
  module OpenidAuth
    extend ActiveSupport::Concern
    TOKEN_REGEX = /^Bearer (\S+)$/.freeze

    included do
      before_action :validate_auth_token!
    end

    def audience_url
      "#{request.base_url == 'https://api.va.gov' ? 'https://api.va.gov' : 'https://sandbox-api.va.gov'}/services/claims"
    end

    def find_auth_token!
      token_value = request.authorization.to_s[TOKEN_REGEX, 1]
      raise ::Common::Exceptions::Unauthorized if token_value.blank?

      token_value
    end

    def auth_token
      @auth_token ||= find_auth_token!
    end

    def token_validation_client
      @client ||= AppealsApi::TokenValidationClient.new(api_key: Settings.modules_appeals_api.token_validation.api_key)
    end

    # If needed, override this in individual controllers to return a list of required OAuth
    # scopes based on the context.
    # FIXME: replace these with actual scopes
    #
    # @return [Array<String>] OAuth scopes required for a successful current request
    def oauth_scopes
      {
        GET: %w[claim.read],
        PUT: %w[claim.write],
        POST: %w[claim.write]
      }[request.method.to_sym]
    end

    def validate_auth_token!
      token_validation_client.validate_token!(
        audience: audience_url,
        scopes: oauth_scopes,
        token: auth_token
      )
    end
  end
end
