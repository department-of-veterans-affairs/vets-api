# frozen_string_literal: true

require 'rx/client'

module MyHealth
  class RxController < ApplicationController
    include ActionController::Serialization
    include MHVControllerConcerns

    protected

    def client
      @client ||= Rx::Client.new(session: { user_id: current_user.mhv_correlation_id })
    end

    def authorize
      raise_access_denied unless current_user.authorize(:mhv_prescriptions, :access?)
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to prescriptions'
    end
  end
end
