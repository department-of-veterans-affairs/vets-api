# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'
require 'common/exceptions'

module OpenidAuth
  module V2
    class ValidationController < ApplicationController
      before_action :validate_strict_audience, :validate_user

      def index
        render json: validated_payload, serializer: OpenidAuth::ValidationSerializerV2
      rescue => e
        raise Common::Exceptions::InternalServerError, e
      end

      def valid_strict?
        %w[true false].include?(fetch_strict)
      end

      def fetch_strict
        params['strict'] || 'false'
      end

      def valid_audience?
        aud = fetch_aud
        if fetch_strict == 'true'
          if aud.nil?
            false
          else
            [*aud].include?(token.payload['aud'])
          end
        else
          true
        end
      end

      def validate_strict_audience
        raise error_klass('Invalid strict value') unless valid_strict?
        raise error_klass('Invalid audience') unless valid_audience?
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
    end
  end
end
