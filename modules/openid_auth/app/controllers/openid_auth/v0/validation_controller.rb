# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'

module OpenidAuth
  module V0
    class ValidationController < ApplicationController
      def index
        render json: token_payload
      rescue StandardError
        raise_error!
      end

      private

      def raise_error!
        raise Common::Exceptions::BackendServiceException.new(
          'AUTH_STATUS502',
          source: self.class.to_s
        )
      end

      def validated_payload
        @validated_payload ||= {
          validated_token: token_payload,
          va_identifiers: {}
        }
      end
    end
  end
end
