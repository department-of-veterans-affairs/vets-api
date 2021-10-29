# frozen_string_literal: true

module V1
  class NotificationsController < ApplicationController
    BEARER_PATTERN = /^Bearer /.freeze

    skip_before_action :verify_authenticity_token, only: [:create]
    skip_before_action :authenticate, only: [:create]
    skip_after_action :set_csrf_header, only: [:create]
    before_action :authenticate_jwt, only: [:create]

    def create
      render text: 'OK'
    end

    private

    def authenticity_error
      Common::Exceptions::Forbidden.new(detail: 'Invalid Authenticity Token')
    end

    def get_bearer_token
      header = request.authorization
      header.gsub(BEARER_PATTERN, '') if header&.match(BEARER_PATTERN)
    end

    def public_key
      @public_key ||= OpenSSL::PKey::EC.new(Settings.notifications.public_key)
    end

    def authenticate_jwt
      bearer_token = get_bearer_token
      raise authenticity_error if bearer_token.blank?

      decoded = JWT.decode(bearer_token, public_key, true, { algorithm: 'ES256' })

      raise authenticity_error unless decoded[0] == { 'user' => 'va_notify' }
    rescue JWT::DecodeError
      raise authenticity_error
    end
  end
end
