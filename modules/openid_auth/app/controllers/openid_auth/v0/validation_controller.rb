# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'
require 'mvi/errors/errors'

module OpenidAuth
  module V0
    class ValidationController < ApplicationController
      def index
        raise StandardError unless user_icn = @current_user.icn
        render json: validated_payload(user_icn), serializer: OpenidAuth::ValidationSerializer
      rescue StandardError
        raise_error!
      end

      private

      def raise_error!
        raise Common::Exceptions::BackendServiceException.new(
          'MHV_STATUS502',
          source: self.class.to_s
        )
      end

      def validated_payload(user_icn)
        @validated_payload ||= OpenStruct.new(token_payload.merge(va_identifiers: { icn: user_icn }))
      end
    end
  end
end
