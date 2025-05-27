# frozen_string_literal: true

module SignIn
  module Webhooks
    class LogingovController < SignIn::ServiceAccountApplicationController
      before_action :authenticate_service_account

      def risc
        head :accepted
      end

      private

      def authenticate_service_account
        jwt = request.raw_post
        @risc_jwt = SignIn::Logingov::Service.new.jwt_decode(jwt)
      rescue => e
        Rails.logger.error('[SignIn][Webhooks][LogingovController] error', e)
        render json: { error: e.message }, status: :unauthorized
      end
    end
  end
end
