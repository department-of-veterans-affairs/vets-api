# frozen_string_literal: true

require 'sm/client'

module MyHealth
  class SMController < ApplicationController
    include ActionController::Serialization
    include MyHealth::MHVControllerConcerns
    service_tag 'mhv-messaging'

    protected

    def client
      @client ||= SM::Client.new(session: { user_id: current_user.mhv_correlation_id })
    end

    def authorize
      raise_access_denied unless MHVMessagingPolicy.new(current_user).access?(client)
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to messaging'
    end

    def use_cache?
      params[:useCache]&.downcase == 'true'
    end
  end
end
