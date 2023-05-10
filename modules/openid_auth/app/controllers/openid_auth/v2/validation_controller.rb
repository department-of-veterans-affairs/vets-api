# frozen_string_literal: true

require 'common/exceptions'
require 'rest-client'
require 'json'
require 'lighthouse/charon/service'

module OpenidAuth
  module V2
    class ValidationController < ApplicationController
      before_action :validate_strict_audience, :validate_user

      def index
        render json: validated_payload, serializer: OpenidAuth::ValidationSerializerV2
      rescue Common::Exceptions::TokenValidationError => e
        raise e
      rescue => e
        raise Common::Exceptions::InternalServerError, e
      end

      def act_vista_id_match_pattern
        /\d{3}[A-Z]*\|\d+\^[A-Z]{2}\^\d{3}[A-Z]*\^[A-Z]{5}\|[A-Z]{1}/
      end

      def parsed_sta3n_match_pattern
        /\d{3}[A-Z]*/
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

      def populate_act_payload(payload_object)
        payload_object.act[:icn] = token.payload['icn']
        payload_object.act[:npi] = token.payload['npi']
        payload_object.act[:sec_id] = token.payload['sub']
        payload_object.act[:vista_id] = token.payload['vista_id']
        payload_object.act[:type] = 'user'
        payload_object
      end

      def validated_payload
        # Ensure the token has `act` and `launch` keys.
        payload_object = setup_structure
        return populate_static_structure(payload_object) if token.static?

        if token.ssoi_token?
          payload_object = populate_act_payload(payload_object)
          return payload_object unless
            should_validate_with_charon?(payload_object.aud) && !authorized_by_charon?(payload_object)

          raise error_klass('Invalid request')
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

      def populate_static_structure(payload_object)
        if payload_object.scp.include?('launch') || payload_object.scp.include?('launch/patient')
          payload_object.act[:icn] = payload_object.icn if payload_object.icn
          payload_object.launch[:patient] = payload_object.icn if payload_object.icn
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

      #
      # Screens the payload, for an additional authorization
      # check with charon
      #
      def authorized_by_charon?(payload_object)
        act_vista_id = payload_object.act[:vista_id]
        sta3n = payload_object.launch['sta3n']
        return false unless !act_vista_id.nil? && !sta3n.nil?

        vista_ids = act_vista_id.scan(act_vista_id_match_pattern)
        return false unless vista_ids

        vista_ids.each do |vista_id|
          parsed_sta3n = vista_id.match(parsed_sta3n_match_pattern)
          if sta3n.to_s.eql?(parsed_sta3n.to_s)
            duz = vista_id.match(/\|\d+\^/).to_s.match(/\d+/)
            return validation_from_charon(duz, sta3n)
          end
        end
        false
      end

      def should_validate_with_charon?(aud)
        return false unless !Settings.oidc.charon.enabled.nil? && Settings.oidc.charon.enabled.eql?(true)

        [*Settings.oidc.charon.audience].include?(aud)
      end

      def get_charon_response(duz, site)
        response = @session.charon_response
        if response.nil?
          begin
            response = Charon::Service.new.call_charon(duz, site)
            @session.charon_response = response
            @session.save
          rescue => e
            log_message_to_sentry("Error retrieving charon context for OIDC token: #{e.message}", :error)
            raise Common::Exceptions::TokenValidationError.new(
              status: 500, code: 500, detail: 'Failed validation with Charon.'
            )
          end
        end

        response
      end

      def validation_from_charon(duz, site)
        response = get_charon_response(duz, site)
        case response.status
        when 200
          true
        when 400
          raise error_klass(response.body['message'])
        when 401, 403
          raise error_klass("Charon menu-code: #{response.body['value']}")
        else
          raise Common::Exceptions::TokenValidationError.new(
            status: 500, code: 500, detail: 'Failed validation with Charon.'
          )
        end
      end
    end
  end
end
