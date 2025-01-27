# frozen_string_literal: true

module V0
  class OnsiteNotificationsController < ApplicationController
    service_tag 'on-site-notifications'
    BEARER_PATTERN = /^Bearer /

    skip_before_action :verify_authenticity_token, only: [:create]
    skip_before_action :authenticate, only: [:create]
    skip_after_action :set_csrf_header, only: [:create]
    before_action :authenticate_jwt, only: [:create]

    def index
      clean_pagination_params
      notifications = OnsiteNotification
                      .for_user(current_user, include_dismissed: params[:include_dismissed])
                      .paginate(**pagination_params)

      options = { meta: pagination_meta(notifications) }

      render json: OnsiteNotificationSerializer.new(notifications, options)
    end

    def create
      onsite_notification = OnsiteNotification.new(
        params.require(:onsite_notification).permit(:va_profile_id, :template_id)
      )

      raise Common::Exceptions::ValidationErrors, onsite_notification unless onsite_notification.save

      render json: OnsiteNotificationSerializer.new(onsite_notification)
    end

    def update
      onsite_notification = OnsiteNotification.find_by(id: params[:id], va_profile_id: current_user.vet360_id)
      raise Common::Exceptions::RecordNotFound, params[:id] if onsite_notification.nil?

      unless onsite_notification.update(params.require(:onsite_notification).permit(:dismissed))
        raise Common::Exceptions::ValidationErrors, onsite_notification
      end

      render json: OnsiteNotificationSerializer.new(onsite_notification)
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

    def clean_pagination_params
      per_page = pagination_params[:per_page].to_i
      params[:per_page] = WillPaginate.per_page if per_page < 1
      WillPaginate::PageNumber(pagination_params[:page])
    rescue WillPaginate::InvalidPage
      params[:page] = 1
    end

    def pagination_meta(notifications)
      {
        pagination: {
          current_page: notifications.current_page.to_i,
          per_page: notifications.per_page,
          total_pages: notifications.total_pages,
          total_entries: notifications.total_entries
        }
      }
    end
  end
end
