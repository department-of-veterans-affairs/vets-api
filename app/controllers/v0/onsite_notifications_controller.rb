# frozen_string_literal: true

module V0
  class OnsiteNotificationsController < ApplicationController
    BEARER_PATTERN = /^Bearer /

    skip_before_action :verify_authenticity_token, only: [:create]
    skip_before_action :authenticate, only: [:create]
    skip_after_action :set_csrf_header, only: [:create]
    before_action :authenticate_jwt, only: [:create]

    def index
      notifications = OnsiteNotification.for_user(current_user, include_dismissed: params[:include_dismissed])
      render(json: notifications)
    end

    def update
      onsite_notification = OnsiteNotification.find_by(id: params[:id], va_profile_id: current_user.vet360_id)
      raise Common::Exceptions::RecordNotFound, params[:id] if onsite_notification.nil?

      unless onsite_notification.update(params.require(:onsite_notification).permit(:dismissed))
        raise Common::Exceptions::ValidationErrors, onsite_notification
      end

      render(json: onsite_notification)
    end

    def create
      onsite_notification = OnsiteNotification.new(
        params.require(:onsite_notification).permit(:va_profile_id, :template_id)
      )

      raise Common::Exceptions::ValidationErrors, onsite_notification unless onsite_notification.save

      render(json: onsite_notification)
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
      OpenSSL::PKey::EC.new(
        Base64.decode64(Settings.onsite_notifications.public_key)
      )
    end

    def authenticate_jwt
      bearer_token = get_bearer_token
      raise authenticity_error if bearer_token.blank?

      decoded_token = JWT.decode(bearer_token, public_key, true, { algorithm: 'ES256' })

      raise authenticity_error unless token_valid? decoded_token
    rescue JWT::DecodeError
      raise authenticity_error
    end

    def token_valid?(token)
      token.first['user'] == 'va_notify' && token.first['iat'].present? && token.first['exp'].present?
    end
  end
end
