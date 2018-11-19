# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'
require 'awesome_print'

module OpenidAuth
  module V0
    class ValidationController < ApplicationController
      def index
        case @current_user.va_profile_status
        when 'OK'
          render json: validated_payload, serializer: OpenidAuth::ValidationSerializer
        when 'server_error'
          raise_error!
        when 'not_found'
          raise_not_found!
        else
          raise_not_found!
        end
      rescue StandardError
        raise_error!
      end

      private

      def raise_not_found!
        raise Common::Exceptions::BackendServiceException.new(
          'AUTHTOKEN_404',
          source: self.class.to_s
        )
      end

      def raise_error!
        raise Common::Exceptions::BackendServiceException.new(
          'AUTHTOKEN_502',
          source: self.class.to_s
        )
      end

      def validated_payload
        @validated_payload ||= OpenStruct.new(token_payload.merge(va_identifiers: { icn: @current_user.icn }))
      end
    end
  end
end
