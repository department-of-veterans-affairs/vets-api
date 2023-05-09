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
        per_page: params[:per_page]
      }
    end
  end
end
