# frozen_string_literal: true

require 'sign_in/logger'

module SignIn
  module Authentication
    extend ActiveSupport::Concern

    BEARER_PATTERN = /^Bearer /.freeze

    included do
      before_action :authenticate
    end

    protected

    def authenticate
      @access_token = authenticate_access_token
      @current_user = load_user
    rescue SignIn::Errors::AccessTokenExpiredError => e
      render json: { errors: e }, status: :forbidden
    rescue SignIn::Errors::StandardError => e
      handle_authenticate_error(e)
    end

    private

    def bearer_token(with_validation: true)
      header = request.authorization
      access_token_jwt = header.gsub(BEARER_PATTERN, '') if header&.match(BEARER_PATTERN)
      SignIn::AccessTokenJwtDecoder.new(access_token_jwt: access_token_jwt).perform(with_validation: with_validation)
    end

    def authenticate_access_token
      bearer_token
    end

    def load_user
      SignIn::UserLoader.new(access_token: @access_token).perform
    end

    def handle_authenticate_error(error)
      context = { authorization: request.authorization }
      log_message_to_sentry(error.message, :error, context)
      render json: { errors: error }, status: :unauthorized
    end

    def sign_in_logger
      @sign_in_logger = SignIn::Logger.new
    end
  end
end
