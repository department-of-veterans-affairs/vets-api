# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'

module OpenidAuth
  module V0
    class ValidationController < ApplicationController
      def index
        begin
          render json: validated_payload, serializer: OpenidAuth::ValidationSerializer
        rescue StandardError => e
          raise Common::Exceptions::InternalServerError, e
        end
      end

      private

      def validated_payload
        @validated_payload ||= OpenStruct.new(token_payload.merge(va_identifiers: { icn: @current_user.icn }))
      end
    end
  end
end
