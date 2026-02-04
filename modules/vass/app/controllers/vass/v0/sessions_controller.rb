# frozen_string_literal: true

module Vass
  module V0
    ##
    # Controller for OTP-based session management (One-Time Password).
    #
    # Handles the generation and validation of One-Time Passwords (OTP)
    # for non-authenticated users who need to verify their identity
    # before scheduling appointments.
    #
    class SessionsController < Vass::ApplicationController
      include Vass::JwtAuthentication
      include Vass::MetricsTracking

      rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

      ##
      # POST /vass/v0/request-otp
      #
      # Validates veteran identity and generates an OTP.
      #
      # Flow:
      # 1. Accepts UUID (veteran_id from welcome email), last_name, and dob
      # 2. Calls VASS GetVeteran to fetch veteran info using UUID
      # 3. Validates last_name and dob match VASS response
      # 4. Extracts contact info (email) from VASS response
      # 5. Generates OTP and sends via VANotify
      #
      # @param uuid [String] Veteran UUID from welcome email
      # @param last_name [String] Veteran's last name for validation
      # @param dob [String] Veteran's date of birth for validation (YYYY-MM-DD)
      #
      # @return [JSON] Success message and expiration time per spec
      #
      def request_otp
        validate_required_params!(:uuid, :last_name, :dob)
        session = Vass::V0::Session.build(data: permitted_params)
        check_all_rate_limits(session.uuid)
        process_otp_creation(session)
        complete_otp_creation(session)
        render_request_otp_success(session)
      rescue Vass::Errors::RateLimitError => e
        handle_request_otp_error(e, session, :rate_limit)
      rescue Vass::Errors::IdentityValidationError => e
        handle_request_otp_error(e, session, :identity_validation)
      rescue Vass::Errors::MissingContactInfoError => e
        handle_request_otp_error(e, session, :missing_contact)
      rescue *vass_api_exceptions => e
        handle_request_otp_error(e, session, :vass_api)
      rescue VANotify::Error => e
        handle_request_otp_error(e, session, :vanotify)
      end

      ##
      # POST /vass/v0/authenticate-otp
      #
      # Validates the OTP provided by the user.
      # On success, generates a JWT token for authenticated access.
      #
      # @param uuid [String] Veteran UUID
      # @param last_name [String] Veteran's last name
      # @param dob [String] Veteran's date of birth (YYYY-MM-DD)
      # @param otp [String] User-provided OTP
      #
      # @return [JSON] JWT token and expiration per spec
      #
      def authenticate_otp
        validate_required_params!(:uuid, :last_name, :dob, :otp)
        session = Vass::V0::Session.build(data: permitted_params_for_auth)
        check_validation_rate_limit(session.uuid)
        return unless validate_otp_session(session)

        jwt_result = session.validate_and_generate_jwt
        jwt_token = jwt_result[:token]
        jti = jwt_result[:jti]
        session.create_authenticated_session(jti:)
        handle_successful_authentication(session, jwt_token, jti)
      rescue Vass::Errors::RateLimitError => e
        handle_authenticate_otp_error(e, session, :rate_limit)
      rescue Vass::Errors::AuthenticationError => e
        handle_authenticate_otp_error(e, session, :authentication)
      rescue *vass_api_exceptions => e
        handle_authenticate_otp_error(e, session, :vass_api)
      rescue Vass::Errors::RedisError, Vass::Errors::AuditLogError => e
        track_failure(SESSIONS_AUTHENTICATE_OTP, error_type: e.class.name)
        raise
      end

      ##
      # POST /vass/v0/revoke-token
      #
      # Revokes an active JWT token (logout functionality).
      # Deletes the session from Redis, making the token invalid for future requests.
      #
      # @return [JSON] Success message or error
      #
      def revoke_token
        token = extract_token_from_header
        return render_invalid_token_response unless token

        payload = decode_jwt_for_revocation(token)
        return render_invalid_token_response unless payload

        uuid = payload['sub']
        return render_invalid_token_response unless uuid && redis_client.session_exists?(uuid:)

        redis_client.delete_session(uuid:)
        log_vass_event(action: 'token_revoked', vass_uuid: uuid, jti: payload['jti'])
        track_success(SESSIONS_REVOKE_TOKEN)
        render_camelized_json({ data: { message: 'Token successfully revoked' } })
      rescue Vass::Errors::RedisError => e
        track_failure(SESSIONS_REVOKE_TOKEN, error_type: e.class.name)
        raise
      end

      private

      ##
      # Renders invalid token error response.
      #
      def render_invalid_token_response
        render_session_error_response(
          code: 'invalid_token',
          detail: 'Token is invalid or already revoked',
          status: :unauthorized
        )
      end

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
      # Permitted parameters for OTP request.
      #
      # @return [Hash] Permitted params
      #
      def permitted_params
        params.permit(:uuid, :last_name, :dob)
      end

      ##
      # Permitted parameters for OTP authentication.
      #
      # @return [Hash] Permitted params
      #
      def permitted_params_for_auth
        params.permit(:uuid, :last_name, :dob, :otp)
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
      # Processes OTP creation: fetches veteran info, validates identity, sets contact info, generates and sends OTP.
      #
      # @param session [Vass::V0::Session] Session instance
      #
      def process_otp_creation(session)
        # Fetch veteran info using only UUID
        veteran_data = appointments_service.get_veteran_info(veteran_id: session.uuid)

        # Validate submitted last_name and dob against fetched veteran data
        session.validate_identity_against_veteran_data(veteran_data)

        session.set_contact_from_veteran_data(veteran_data)
        otp_code = session.generate_and_save_otp
        Rails.logger.info("VASS OTP Generated for UUID #{session.uuid}: #{otp_code}") if Rails.env.development?
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
        log_vass_event(action: 'otp_generated', vass_uuid: session.uuid)
      end

      ##
      # Renders successful OTP request response with obfuscated email.
      #
      # @param session [Vass::V0::Session] Session instance
      #
      def render_request_otp_success(session)
        otp_expiry_seconds = redis_client.redis_otp_expiry.to_i
        response_data = camelize_keys({
                                        data: {
                                          message: 'OTP sent to registered email address',
                                          expires_in: otp_expiry_seconds,
                                          email: obfuscate_email(session.contact_value)
                                        }
                                      })
        track_success(SESSIONS_REQUEST_OTP)
        render json: response_data, status: :ok
      end

      ##
      # Handles identity validation errors.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param error [Vass::Errors::IdentityValidationError] Error
      #
      def handle_identity_validation_error(session, _error)
        log_vass_event(action: 'identity_validation_failed', vass_uuid: session.uuid, level: :warn)
        render_session_error_response(
          code: 'invalid_credentials',
          detail: 'Unable to verify identity. Please check your information.',
          status: :unauthorized
        )
      end

      ##
      # Handles missing contact info errors.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param error [Vass::Errors::MissingContactInfoError] Error
      #
      def handle_missing_contact_info_error(session, _error)
        log_vass_event(action: 'missing_contact_info', vass_uuid: session.uuid, level: :error)
        render_session_error_response(
          code: 'missing_contact_info',
          detail: 'No contact information available for this veteran.',
          status: :unprocessable_entity
        )
      end

      ##
      # Handles VASS API errors.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param error [Exception] Error
      #
      def handle_vass_api_error(session, error)
        log_vass_event(action: 'vass_api_error', vass_uuid: session.uuid, level: :error,
                       error_class: error.class.name)
        render_session_error_response(
          code: 'service_error',
          detail: 'VASS service error',
          status: :bad_gateway
        )
      end

      ##
      # Handles successful OTP authentication.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param jwt_token [String] Generated JWT token
      # @param jti [String] JWT ID for audit logging
      #
      def handle_successful_authentication(session, jwt_token, jti)
        reset_validation_rate_limit(session.uuid)
        log_vass_event(action: 'jwt_issued', vass_uuid: session.uuid, jti:)
        expires_in = redis_client.redis_session_expiry.to_i
        response_data = camelize_keys({
                                        data: {
                                          token: jwt_token,
                                          expires_in:,
                                          token_type: 'Bearer'
                                        }
                                      })
        track_success(SESSIONS_AUTHENTICATE_OTP)
        render json: response_data, status: :ok
      end

      ##
      # Handles VANotify errors in request_otp action.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param error [VANotify::Error] VANotify error
      #
      def handle_vanotify_error(session, error)
        log_vass_event(
          action: 'vanotify_error',
          vass_uuid: session.uuid,
          level: :error,
          error_class: error.class.name,
          status_code: error.status_code,
          contact_method: session.contact_method
        )
        status = map_vanotify_status_to_http_status(error.status_code)
        render_session_error_response(
          code: 'notification_error',
          detail: 'Unable to send notification. Please try again later.',
          status:
        )
      end

      ##
      # Handles request_otp errors by tracking and routing to appropriate handler.
      #
      # @param error [Exception] The error that occurred
      # @param session [Vass::V0::Session] The session object
      # @param error_type [Symbol] Type of error (:rate_limit, :identity_validation, etc.)
      #
      def handle_request_otp_error(error, session, error_type)
        track_failure(SESSIONS_REQUEST_OTP, error_type: error.class.name)
        case error_type
        when :rate_limit then handle_rate_limit_error_for_generation(session, error)
        when :identity_validation
          increment_rate_limit(session.uuid)
          handle_identity_validation_error(session, error)
        when :missing_contact then handle_missing_contact_info_error(session, error)
        when :vass_api then handle_vass_api_error(session, error)
        when :vanotify then handle_vanotify_error(session, error)
        end
      end

      ##
      # Handles authenticate_otp errors by tracking and routing to appropriate handler.
      #
      # @param error [Exception] The error that occurred
      # @param session [Vass::V0::Session] The session object
      # @param error_type [Symbol] Type of error (:rate_limit, :authentication, :vass_api)
      #
      def handle_authenticate_otp_error(error, session, error_type)
        track_failure(SESSIONS_AUTHENTICATE_OTP, error_type: error.class.name)
        case error_type
        when :rate_limit then handle_validation_rate_limit_error(session, error)
        when :authentication then handle_invalid_otp(session)
        when :vass_api
          log_vass_event(action: 'vass_api_error', vass_uuid: session.uuid, level: :error,
                         error_class: error.class.name)
          render_session_error_response(code: 'service_error', detail: 'VASS service error', status: :bad_gateway)
        end
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
      # Checks both generation and validation rate limits.
      #
      # @param identifier [String] UUID to check (rate limited per veteran)
      # @raise [Vass::Errors::RateLimitError] if either limit exceeded
      #
      def check_all_rate_limits(identifier)
        check_rate_limit(identifier)
        check_validation_rate_limit(identifier)
      end

      ##
      # Checks if rate limit has been exceeded for the identifier.
      #
      # @param identifier [String] UUID to check (rate limited per veteran)
      # @raise [Vass::Errors::RateLimitError] if limit exceeded
      #
      def check_rate_limit(identifier)
        return unless redis_client.rate_limit_exceeded?(identifier:)

        log_rate_limit_exceeded(identifier)
        track_infrastructure_metric(RATE_LIMIT_GENERATION_EXCEEDED)
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
      # Handles missing parameter errors from Rails params.require().
      #
      # @param _exception [ActionController::ParameterMissing] The exception (unused)
      #
      def handle_parameter_missing(_exception)
        render_session_error_response(
          code: 'missing_parameter',
          detail: 'Required parameter is missing',
          status: :bad_request
        )
      end

      ##
      # Validates OTP session (checks for expiry).
      # The actual OTP validation and deletion happens atomically in validate_and_generate_jwt.
      #
      # @param session [Vass::V0::Session] Session instance
      # @return [Boolean] true if valid, false otherwise
      #
      def validate_otp_session(session)
        return handle_expired_otp(session) if session.otp_expired?

        true
      end

      ##
      # Handles expired OTP.
      #
      # @param session [Vass::V0::Session] Session instance
      # @return [Boolean] false
      #
      def handle_expired_otp(session)
        log_vass_event(action: 'otp_expired', vass_uuid: session.uuid, level: :warn)
        track_infrastructure_metric(SESSION_OTP_EXPIRED)
        render_session_error_response(
          code: 'otp_expired',
          detail: 'OTP has expired. Please request a new one.',
          status: :unauthorized
        )
        false
      end

      ##
      # Handles invalid OTP submission.
      #
      # @param session [Vass::V0::Session] Session instance
      # @return [Boolean] false
      #
      def handle_invalid_otp(session)
        increment_validation_rate_limit(session.uuid)
        log_invalid_otp(session.uuid)
        track_infrastructure_metric(SESSION_OTP_INVALID)

        attempts_remaining = redis_client.validation_attempts_remaining(identifier: session.uuid)
        render_session_error_response(
          code: 'invalid_otp',
          detail: 'Invalid OTP. Please try again.',
          status: :unauthorized,
          attempts_remaining:
        )
        false
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
      # @param uuid [String] Veteran UUID
      #
      def log_invalid_otp(uuid)
        log_vass_event(action: 'invalid_otp', vass_uuid: uuid, level: :warn)
      end

      ##
      # Renders error response in API spec format.
      #
      # @param code [String] Error code
      # @param detail [String] Error detail message
      # @param status [Symbol] HTTP status symbol
      # @param retry_after [Integer, nil] Retry after seconds (optional)
      # @param attempts_remaining [Integer, nil] Attempts remaining (optional)
      #
      def render_session_error_response(code:, detail:, status:, retry_after: nil, attempts_remaining: nil)
        error = { code:, detail: }
        error[:retry_after] = retry_after if retry_after
        error[:attempts_remaining] = attempts_remaining if attempts_remaining

        render_camelized_json({ errors: [error] }, status:)
      end

      ##
      # Logs rate limit exceeded (no PHI).
      #
      # @param identifier [String] Identifier (UUID) for the rate limit
      #
      def log_rate_limit_exceeded(identifier)
        log_vass_event(action: 'rate_limit_exceeded', vass_uuid: identifier, level: :warn)
      end

      ##
      # Checks if validation rate limit has been exceeded for the identifier.
      #
      # @param identifier [String] UUID to check (rate limited per veteran)
      # @raise [Vass::Errors::RateLimitError] if limit exceeded
      #
      def check_validation_rate_limit(identifier)
        return unless redis_client.validation_rate_limit_exceeded?(identifier:)

        log_validation_rate_limit_exceeded(identifier)
        track_infrastructure_metric(RATE_LIMIT_VALIDATION_EXCEEDED)
        raise Vass::Errors::RateLimitError, 'Rate limit exceeded for OTP validation attempts'
      end

      ##
      # Increments the validation rate limit counter.
      #
      # @param identifier [String] UUID to increment (rate limited per veteran)
      #
      def increment_validation_rate_limit(identifier)
        redis_client.increment_validation_rate_limit(identifier:)
      end

      ##
      # Resets the validation rate limit counter.
      #
      # @param identifier [String] UUID to reset (rate limited per veteran)
      #
      def reset_validation_rate_limit(identifier)
        redis_client.reset_validation_rate_limit(identifier:)
      end

      ##
      # Handles rate limit errors in request_otp, determining which limit was hit.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param error [Vass::Errors::RateLimitError] Error
      #
      def handle_rate_limit_error_for_generation(session, error)
        if redis_client.validation_rate_limit_exceeded?(identifier: session.uuid)
          handle_validation_rate_limit_error(session, error)
        else
          handle_generation_rate_limit_error(session, error)
        end
      end

      ##
      # Handles generation rate limit errors.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param _error [Vass::Errors::RateLimitError] Error (unused)
      #
      def handle_generation_rate_limit_error(session, _error)
        log_rate_limit_exceeded(session.uuid)
        retry_after = Settings.vass.rate_limit_expiry.to_i
        render_session_error_response(
          code: 'rate_limit_exceeded',
          detail: 'Too many OTP requests. Please try again later.',
          status: :too_many_requests,
          retry_after:
        )
      end

      ##
      # Handles validation rate limit errors.
      #
      # @param session [Vass::V0::Session] Session instance
      # @param _error [Vass::Errors::RateLimitError] Error (unused)
      #
      def handle_validation_rate_limit_error(session, _error)
        log_validation_rate_limit_exceeded(session.uuid)
        retry_after = Settings.vass.rate_limit_expiry.to_i
        render_session_error_response(
          code: 'account_locked',
          detail: 'Too many failed attempts. Please request a new OTP.',
          status: :too_many_requests,
          retry_after:
        )
      end

      ##
      # Logs validation rate limit exceeded (no PHI).
      #
      # @param identifier [String] Identifier (UUID) for the rate limit
      #
      def log_validation_rate_limit_exceeded(identifier)
        log_vass_event(action: 'validation_rate_limit_exceeded', vass_uuid: identifier, level: :warn)
      end

      ##
      # Obfuscates an email address for display.
      # Shows the first character and domain, masks the rest.
      #
      # @example
      #   obfuscate_email('charles@agile6.com') #=> 'c******@agile6.com'
      #   obfuscate_email('ab@example.com') #=> 'a*@example.com'
      #
      # @param email [String, nil] Email address to obfuscate
      # @return [String, nil] Obfuscated email or nil if input is nil/invalid
      #
      def obfuscate_email(email)
        return nil if email.blank?

        parts = email.split('@')
        return nil if parts.length != 2

        local_part = parts[0]
        domain = parts[1]

        return nil if local_part.empty? || domain.empty?

        if local_part.length <= 1
          "#{local_part}@#{domain}"
        else
          "#{local_part[0]}#{'*' * (local_part.length - 1)}@#{domain}"
        end
      end
    end
  end
end
