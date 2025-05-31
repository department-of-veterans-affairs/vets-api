# frozen_string_literal: true

require 'sign_in/logingov/service'

module SignIn
  module Webhooks
    class LogingovController < SignIn::ServiceAccountApplicationController
      Mime::Type.register 'application/secevent+jwt', :secevent_jwt
      service_tag 'identity'
      before_action :authenticate_service_account

      def risc
        Logingov::RiscEventHandler.new(payload: @risc_jwt).perform

        head :accepted
      rescue SignIn::Errors::LogingovRiscEventHandlerError => e
        render_error(e.message, :unprocessable_entity)
      end

      private

      def authenticate_service_account
        @risc_jwt = Logingov::Service.new.jwt_decode(request.raw_post)
      rescue => e
        render_error(e.message, :unauthorized)
      end

      def render_error(error_message, status)
        Rails.logger.error("[SignIn][Webhooks][LogingovController] #{action_name} error", error_message:)
        render json: { error: 'Failed to process RISC event' }, status:
      end
    end
  end
end
