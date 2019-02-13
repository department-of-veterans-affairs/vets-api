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

      def validated_payload
        # Ensure the token has an `va_identifiers` key.
        payload_object = OpenStruct.new(token_payload.merge(va_identifiers: { icn: nil }))

        # Sometimes we'll already have an `icn` in the token. If we do, copy if down into `va_identifiers`
        # for consistency. Otherwise use the ICN value we used to look up the MVI attributes.
        payload_object.va_identifiers[:icn] = payload_object.try(:icn) || @current_user.icn
        payload_object
      end
    end
  end
end
