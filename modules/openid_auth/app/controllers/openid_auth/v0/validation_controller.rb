# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'
require 'common/exceptions'

module OpenidAuth
  module V0
    class ValidationController < ApplicationController
      before_action :validate_user

      def index
        render json: validated_payload, serializer: OpenidAuth::ValidationSerializer
      rescue => e
        raise Common::Exceptions::InternalServerError, e
      end

      private

      def validated_payload
        # Ensure the token has an `va_identifiers` key.
        payload_object = OpenStruct.new(token.payload.merge(va_identifiers: { icn: nil }))

        # Sometimes we'll already have an `icn` in the token. If we do, copy if down into `va_identifiers`
        # for consistency. Otherwise use the ICN value we used to look up the MVI attributes.
        payload_object.va_identifiers[:icn] = payload_object.try(:icn)

        # Client Credentials token will not populate the @current_user, so only fill if not that token type
        unless token.client_credentials_token? || !payload_object[:icn].nil?
          payload_object.va_identifiers[:icn] = @current_user.icn
        end

        payload_object
      end
    end
  end
end
