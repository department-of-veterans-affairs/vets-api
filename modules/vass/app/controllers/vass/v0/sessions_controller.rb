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

        return unless validate_otp_session(session)

        session_token = session.validate_and_process_otp
        session.create_authenticated_session(session_token:)

        log_vass_event(action: 'otp_validated', uuid: session.uuid)
        increment_statsd('otp_validation_success')
        render json: session.validation_response(session_token:), status: :ok
      rescue *vass_api_exceptions => e
        log_vass_event(action: 'vass_api_error', uuid: session.uuid, level: :error, error_class: e.class.name)
        render json: { error: true, message: 'VASS service error' }, status: :bad_gateway
      end

      ##
      # POST /vass/v0/sessions
      #
      # Validates veteran identity and generates an OTP code.
      #
      # Flow:
      # 1. Accepts UUID (veteran_id from welcome email), last_name, and date_of_birth
      # 2. Calls VASS GetVeteran to fetch veteran info
      # 3. Validates last_name and date_of_birth match VASS response
      # 4. Extracts contact info (email) from VASS response
      # 5. Generates OTP and sends via VANotify
      #
      # @param uuid [String] Veteran UUID from welcome email
      # @param last_name [String] Veteran's last name for validation
      # @param date_of_birth [String] Veteran's date of birth for validation
      #
      # @return [JSON] Session UUID and success message
      #
      def create
        session = Vass::V0::Session.build(data: permitted_params)

        return unless validate_session_for_creation(session)

        check_rate_limit(session.uuid)
        process_otp_creation(session)
        complete_otp_creation(session)

        render json: session.creation_response, status: :ok
      rescue Vass::Errors::IdentityValidationError => e
        handle_identity_validation_error(session, e)
      rescue Vass::Errors::MissingContactInfoError => e
        handle_missing_contact_info_error(session, e)
      rescue *vass_api_exceptions => e
        handle_vass_api_error(session, e)
      rescue VANotify::Error => e
        handle_vanotify_error(session, e)
      end

      private

      ##
      # Returns array of VASS API exception classes that should be handled uniformly.
      #
      # @return [Array<Class>] Array of exception classes
      #
      def vass_api_exceptions
        [
          Vass::Errors::VassApiError,
          Vass::Errors::ServiceError,
          Vass::Errors::AuthenticationError,
          Vass::Errors::NotFoundError
        ]
      end

      ##
      # Permitted parameters for session creation.
      #
      # @return [Hash] Permitted params
      #
      def permitted_params
        params.require(:session).permit(:uuid, :last_name, :date_of_birth)
      end

      ##
      # Returns the appointments service instance.
      #
      # @return [Vass::AppointmentsService] Appointments service
      #
      def appointments_service
        @appointments_service ||= Vass::AppointmentsService.build(correlation_id: @correlation_id)
      end

      ##
      # Returns the VANotify service instance.
      #
      # @return [Vass::VANotifyService] VANotify service
      #
      def vanotify_service
        @vanotify_service ||= Vass::VANotifyService.build
      end

      ##
      # Processes OTP creation: validates veteran, sets contact info, generates and sends OTP.
      #
      # @param session [Vass::V0::Session] Session instance
      #
      def process_otp_creation(session)
        veteran_data = appointments_service.get_veteran_info(
          veteran_id: session.uuid,
          last_name: session.last_name,
          date_of_birth: session.date_of_birth
        )
        session.set_contact_from_veteran_data(veteran_data)
        otp_code = session.generate_and_save_otp
        send_otp_via_vanotify(session, otp_code)
      end

      ##
      # Sends OTP via VANotify service.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param otp_code [String] OTP code to send
      #
      def send_otp_via_vanotify(session, otp_code)
        vanotify_service.send_otp(
          contact_method: session.contact_method,
          contact_value: session.contact_value,
          otp_code:
        )
      end

      ##
      # Completes OTP creation: increments rate limit, logs, and increments stats.
      #
      # @param session [Vass::V0::Session] Session instance
      #
      def complete_otp_creation(session)
        increment_rate_limit(session.uuid)
        log_vass_event(action: 'otp_generated', uuid: session.uuid)
        increment_statsd('otp_generated')
      end

      ##
      # Handles identity validation errors.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param error [Vass::Errors::IdentityValidationError] Error
      #
      def handle_identity_validation_error(session, error)
        log_vass_event(action: 'identity_validation_failed', uuid: session.uuid, level: :warn)
        render json: { error: true, message: error.message }, status: :unauthorized
      end

      ##
      # Handles missing contact info errors.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param error [Vass::Errors::MissingContactInfoError] Error
      #
      def handle_missing_contact_info_error(session, error)
        log_vass_event(action: 'missing_contact_info', uuid: session.uuid, level: :error)
        render json: { error: true, message: error.message }, status: :unprocessable_entity
      end

      ##
      # Handles VASS API errors.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param error [Exception] Error
      #
      def handle_vass_api_error(session, error)
        log_vass_event(action: 'vass_api_error', uuid: session.uuid, level: :error,
                       error_class: error.class.name)
        render json: { error: true, message: 'VASS service error' }, status: :bad_gateway
      end

      ##
      # Handles VANotify errors in create action.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param error [VANotify::Error] VANotify error
      #
      def handle_vanotify_error(session, error)
        log_vass_event(
          action: 'vanotify_error',
          uuid: session.uuid,
          level: :error,
          error_class: error.class.name,
          status_code: error.status_code,
          contact_method: session.contact_method
        )
        increment_statsd('otp_send_failed')
        status = map_vanotify_status_to_http_status(error.status_code)
        render_error_response(
          title: 'Notification Service Error',
          detail: 'Unable to send notification. Please try again later',
          status:
        )
      end

      ##
      # Maps VANotify status codes to HTTP status symbols.
      #
      # @param status_code [Integer] VANotify error status code
      # @return [Symbol] HTTP status symbol
      #
      def map_vanotify_status_to_http_status(status_code)
        case status_code
        when 400
          :bad_request
        when 401, 403
          :unauthorized
        when 404
          :not_found
        when 429
          :too_many_requests
        when 500, 502, 503
          :bad_gateway
        else
          :service_unavailable
        end
      end

      ##
      # Checks if rate limit has been exceeded for the identifier.
      #
      # @param identifier [String] UUID to check (rate limited per veteran)
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
      # @param identifier [String] UUID to increment (rate limited per veteran)
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
      # Validates session for creation.
      #
      # @param session [Vass::V0::Session] Session instance
      # @return [Boolean] true if valid, false otherwise
      #
      def validate_session_for_creation(session)
        return true if session.valid_for_creation?

        log_validation_error
        render json: session.validation_error_response, status: :unprocessable_entity
        false
      end

      ##
      # Validates OTP session.
      #
      # @param session [Vass::V0::Session] Session instance
      # @return [Boolean] true if valid, false otherwise
      #
      def validate_otp_session(session)
        unless session.valid_for_validation?
          log_validation_error
          render json: session.validation_error_response, status: :unprocessable_entity
          return false
        end

        unless session.valid_otp?
          log_invalid_otp(session.uuid)
          increment_statsd('otp_validation_failed')
          render json: session.invalid_otp_response, status: :unauthorized
          return false
        end

        true
      end

      ##
      # Logs validation error (no PHI).
      #
      def log_validation_error
        log_vass_event(action: 'validation_error', level: :warn)
      end

      ##
      # Logs invalid OTP attempt (no PHI).
      #
      # @param uuid [String] Session UUID
      #
      def log_invalid_otp(uuid)
        log_vass_event(action: 'invalid_otp', uuid:, level: :warn)
      end

      ##
      # Logs rate limit exceeded (no PHI).
      #
      def log_rate_limit_exceeded
        log_vass_event(action: 'rate_limit_exceeded', level: :warn)
      end

      ##
      # Increments StatsD metric.
      #
      # @param metric_name [String] Metric name
      #
      def increment_statsd(metric_name)
        StatsD.increment("api.vass.sessions.#{metric_name}", tags: ['service:vass'])
      end
    end
  end
end
