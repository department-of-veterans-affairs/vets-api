# frozen_string_literal: true

require 'mobile/v0/messaging/client'

module Mobile
  class MessagingController < ApplicationController
    include ActionController::Serialization

    before_action :authorize
    before_action :authenticate_client

    protected

    def client
      @client ||= Mobile::V0::Messaging::Client.new(session: { user_id: current_user.mhv_correlation_id })
    end

    def authorize
      raise_access_denied unless current_user.authorize(:mhv_messaging, :access?)
    end

    def raise_access_denied
      Rails.logger.info('SM ACCESS DENIED',
                        account_type: current_user.mhv_account_type,
                        mhv_id: current_user.mhv_correlation_id,
                        sign_in_service: current_user.identity.sign_in[:service_name])
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to messaging'
    end

    def authenticate_client
      client.authenticate if client.session.expired?
    end

    def use_cache?
      params[:useCache]&.downcase == 'true'
    end

    def pagination_params
      {
        page: params[:page],
        per_page: params[:per_page] || 100
      }
    end
  end
end
