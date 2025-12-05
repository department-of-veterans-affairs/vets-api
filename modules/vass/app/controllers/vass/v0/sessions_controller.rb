# frozen_string_literal: true

module Vass
  module V0
    ##
    # Controller for OTP-based session management.
    #
    # Handles the generation and validation of One-Time Passcodes (OTP)
    # for non-authenticated users who need to verify their contact information
    # before scheduling appointments.
    #
    class SessionsController < Vass::ApplicationController
      ##
      # GET /vass/v0/sessions/:id
      #
      # Validates the OTP code provided by the user.
      # On success, generates a session token for authenticated access.
      #
      # @param id [String] Session UUID (from URL)
      # @param otp_code [String] User-provided OTP code
      #
      # @return [JSON] Session token and success message
      #
      def show
        session = Vass::V0::Session.build(
          uuid: params[:id],
          otp_code: params[:otp_code]
        )

        unless session.valid_for_validation?
          log_validation_error
          render json: session.validation_error_response, status: :unprocessable_entity
          return
        end

        unless session.valid_otp?
          log_invalid_otp(session.uuid)
          increment_statsd('otp_validation_failed')
          render json: session.invalid_otp_response, status: :unauthorized
          return
        end

        # Delete OTP after successful validation (one-time use)
        session.delete_otp

        # Generate session token for authenticated access
        session_token = session.generate_session_token

        # TODO: Store session data with veteran info (EDIPI, veteran_id)
        # For now, just return the session token
        # redis_client.save_session(
        #   session_token: session_token,
        #   edipi: veteran_edipi,
        #   veteran_id: veteran_id,
        #   uuid: session.uuid
        # )

        log_otp_validated(session.uuid)
        increment_statsd('otp_validation_success')

        render json: session.validation_response(session_token:), status: :ok
      end

      ##
      # POST /vass/v0/sessions
      #
      # Generates an OTP code, stores it in Redis, and sends it via VANotify.
      #
      # @param contact_method [String] Contact method (email or sms)
      # @param contact_value [String] Email address or phone number
      #
      # @return [JSON] Session UUID and success message
      #
      def create
        session = Vass::V0::Session.build(data: permitted_params)

        unless session.valid_for_creation?
          log_validation_error
          render json: session.validation_error_response, status: :unprocessable_entity
          return
        end

        check_rate_limit(session.contact_value)

        otp_code = session.generate_otp
        session.save_otp(otp_code)

        # Send OTP via VANotify
        send_otp_via_vanotify(session, otp_code)

        increment_rate_limit(session.contact_value)
        log_otp_generated(session.uuid)
        increment_statsd('otp_generated')

        render json: session.creation_response, status: :ok
      end

      private

      ##
      # Permitted parameters for session creation.
      #
      # @return [Hash] Permitted params
      #
      def permitted_params
        params.require(:session).permit(:contact_method, :contact_value)
      end

      ##
      # Checks if rate limit has been exceeded for the identifier.
      #
      # @param identifier [String] Contact value to check
      # @raise [Vass::Errors::RateLimitError] if limit exceeded
      #
      def check_rate_limit(identifier)
        return unless redis_client.rate_limit_exceeded?(identifier:)

        log_rate_limit_exceeded
        increment_statsd('rate_limit_exceeded')
        raise Vass::Errors::RateLimitError, 'Rate limit exceeded for OTP generation'
      end

      ##
      # Increments the rate limit counter.
      #
      # @param identifier [String] Contact value
      #
      def increment_rate_limit(identifier)
        redis_client.increment_rate_limit(identifier:)
      end

      ##
      # Returns the Redis client instance.
      #
      # @return [Vass::RedisClient] Redis client
      #
      def redis_client
        @redis_client ||= Vass::RedisClient.build
      end

      ##
      # Logs OTP generation event (no PHI).
      #
      # @param uuid [String] Session UUID
      #
      def log_otp_generated(uuid)
        Rails.logger.info({
          service: 'vass',
          action: 'otp_generated',
          uuid:,
          controller: controller_name,
          timestamp: Time.current.iso8601
        }.to_json)
      end

      ##
      # Logs OTP validation event (no PHI).
      #
      # @param uuid [String] Session UUID
      #
      def log_otp_validated(uuid)
        Rails.logger.info({
          service: 'vass',
          action: 'otp_validated',
          uuid:,
          controller: controller_name,
          timestamp: Time.current.iso8601
        }.to_json)
      end

      ##
      # Logs invalid OTP attempt (no PHI).
      #
      # @param uuid [String] Session UUID
      #
      def log_invalid_otp(uuid)
        Rails.logger.warn({
          service: 'vass',
          action: 'invalid_otp',
          uuid:,
          controller: controller_name,
          timestamp: Time.current.iso8601
        }.to_json)
      end

      ##
      # Logs validation error (no PHI).
      #
      def log_validation_error
        Rails.logger.warn({
          service: 'vass',
          action: 'validation_error',
          controller: controller_name,
          timestamp: Time.current.iso8601
        }.to_json)
      end

      ##
      # Logs rate limit exceeded (no PHI).
      #
      def log_rate_limit_exceeded
        Rails.logger.warn({
          service: 'vass',
          action: 'rate_limit_exceeded',
          controller: controller_name,
          timestamp: Time.current.iso8601
        }.to_json)
      end

      ##
      # Increments StatsD metric.
      #
      # @param metric_name [String] Metric name
      #
      def increment_statsd(metric_name)
        StatsD.increment("api.vass.sessions.#{metric_name}", tags: ['service:vass'])
      end

      ##
      # Sends OTP code via VANotify using the appropriate contact method.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param otp_code [String] OTP code to send
      # @raise [VANotify::Error] if VANotify fails to send the OTP
      #
      def send_otp_via_vanotify(session, otp_code)
        vanotify_service = Vass::VANotifyService.build
        vanotify_service.send_otp(
          contact_method: session.contact_method,
          contact_value: session.contact_value,
          otp_code:
        )
        log_otp_sent(session.uuid, session.contact_method)
      rescue => e
        log_vanotify_error(session.uuid, e, session.contact_method)
        increment_statsd('otp_send_failed')
        # Raise the error - if VANotify fails, the user won't receive the OTP
        # so the request should fail and they can retry
        raise
      end

      ##
      # Logs successful OTP send event (no PHI).
      #
      # @param uuid [String] Session UUID
      # @param contact_method [String] Contact method used
      #
      def log_otp_sent(uuid, contact_method)
        Rails.logger.info({
          service: 'vass',
          action: 'otp_sent',
          uuid:,
          contact_method:,
          controller: controller_name,
          timestamp: Time.current.iso8601
        }.to_json)
      end

      ##
      # Logs VANotify error (no PHI).
      #
      # @param uuid [String] Session UUID
      # @param error [Exception] Error that occurred
      # @param contact_method [String] Contact method used
      #
      def log_vanotify_error(uuid, error, contact_method = nil)
        error_data = {
          service: 'vass',
          action: 'vanotify_error',
          uuid:,
          error_class: error.class.name,
          controller: controller_name,
          timestamp: Time.current.iso8601
        }
        error_data[:status_code] = error.status_code if error.respond_to?(:status_code)
        error_data[:contact_method] = contact_method if contact_method.present?
        Rails.logger.error(error_data.to_json)
      end
    end
  end
end
