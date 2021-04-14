# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'
require 'common/exceptions'

module OpenidAuth
  module V2
    class ValidationController < ApplicationController
      before_action :validate_user

      def index
        render json: validated_payload, serializer: OpenidAuth::ValidationSerializerV2
      rescue => e
        raise Common::Exceptions::InternalServerError, e
      end

      private

      def validated_payload
        # Ensure the token has `act` and `launch` keys.
        payload_object = setup_structure

        if token.ssoi_token?
          payload_object.act[:icn] = token.payload['icn']
          payload_object.act[:npi] = token.payload['npi']
          payload_object.act[:sec_id] = token.payload['sub']
          payload_object.act[:vista_id] = token.payload['vista_id']
          payload_object.act[:type] = 'user'
          return payload_object
        end

        if token.client_credentials_token?
          payload_object.act[:type] = 'system'
          return payload_object
        end
        # Client Credentials will not populate the @current_user, so only fill if not that token type
        if payload_object[:icn].nil?
          payload_object.act[:icn] = @current_user.icn
          payload_object.launch[:patient] = @current_user.icn
        end

        if validate_with_charon(payload_object.aud)
          additional_clinical_health_token_screen(payload_object)
        end

        payload_object
      end

      def setup_structure
        payload_object = OpenStruct.new(token.payload.merge(act: {}, launch: {}))
        payload_object.act[:icn] = nil
        payload_object.act[:npi] = nil
        payload_object.act[:sec_id] = nil
        payload_object.act[:vista_id] = nil
        payload_object.act[:type] = 'patient'
        if (token.payload['scp'].include?('launch') ||
            token.payload['scp'].include?('launch/patient')) && !token.payload[:launch].nil?
          payload_object.launch = token.payload[:launch]
        end
        payload_object
      end

      def additional_clinical_health_token_screen(payload_object)
        if (payload_object.act['vista_id'].nil? || payload_object.launch['sta3n'].nil?)
          false
        end
        sta3n = payload_object.launch['sta3n']
        if (payload_object.act['vista_id'].not.include?(sta3n))
          false
        end
        true
      end

      def validate_with_charon(aud)
        charon = Settings.oidc.charon
        charon.audience.each { |item|
          aud_check = item['audience']
          if (aud_check.equal?aud)
            true
          end
        }
        false
      end
    end
  end
end
