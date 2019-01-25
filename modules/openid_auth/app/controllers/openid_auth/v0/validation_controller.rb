# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'

module OpenidAuth
  module V0
    class ValidationController < ApplicationController
      before_action :validate_user

      def index
        render json: validated_payload, serializer: OpenidAuth::ValidationSerializer
      rescue StandardError => e
        raise Common::Exceptions::InternalServerError, e
      end

      private

      def payload_object
        @payload_object ||= OpenStruct.new(token_payload.merge(va_identifiers: { icn: nil }))
      end

      def validated_payload
        payload_object.va_identifiers[:icn] = payload_object.try(:icn) || @current_user.icn
        payload_object
      end
    end
  end
end
