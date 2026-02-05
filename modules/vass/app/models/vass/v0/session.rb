# frozen_string_literal: true

module Vass
  module V0
    ##
    # Session model for managing OTP-based authentication flow.
    #
    # This model handles the generation and validation of One-Time Passwords (OTP)
    # for non-authenticated users who need to verify their identity
    # before scheduling appointments.
    #
    # @!attribute uuid
    #   @return [String] Unique session identifier
    # @!attribute contact_method
    #   @return [String] Method of contact (email)
    # @!attribute contact_value
    #   @return [String] Email address or phone number
    # @!attribute otp_code
    #   @return [String] User-provided one-time password (OTP) for validation (aliased as otp)
    # @!attribute redis_client
    #   @return [Vass::RedisClient] Redis client for storage operations
    #
    class Session
      include Vass::Logging

      # Valid contact methods for OTP delivery
      VALID_CONTACT_METHODS = %w[email].freeze

      # Email validation regex (basic RFC 5322 compliant)
      EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

      # OTP code length
      OTP_LENGTH = 6

      attr_accessor :contact_method, :contact_value, :edipi, :veteran_id
      attr_reader :uuid, :last_name, :date_of_birth, :otp_code, :redis_client

      ##
      # Builds a Session instance.
      #
      # @param opts [Hash] Options to create the session
      # @option opts [String] :uuid Veteran UUID (veteran_id from welcome email)
      # @option opts [String] :last_name Veteran's last name for validation
      # @option opts [String] :dob Veteran's date of birth for validation (YYYY-MM-DD)
      # @option opts [String] :otp User-provided OTP for validation
      # @option opts [Vass::RedisClient] :redis_client Optional Redis client
      #
      # @return [Vass::V0::Session] An instance of this class
      #
      def self.build(opts = {})
        new(opts)
      end

      ##
      # Initializes a new Session.
      #
      # @param opts [Hash] Options for initialization
      # @option opts [String] :uuid Veteran UUID (veteran_id from welcome email)
      # @option opts [Hash] :data Data hash containing uuid, last_name, dob
      # @option opts [String] :last_name Veteran's last name
      # @option opts [String] :dob Veteran's date of birth (YYYY-MM-DD)
      # @option opts [String] :date_of_birth Veteran's date of birth (YYYY-MM-DD) - alias for dob
      # @option opts [String] :otp User-provided OTP for validation
      # @option opts [String] :otp_code User-provided OTP for validation - alias for otp
      # @option opts [Vass::RedisClient] :redis_client Optional Redis client
      #
      def initialize(opts = {})
        data = opts[:data] || {}
        @uuid = opts[:uuid] || data[:uuid] || SecureRandom.uuid
        @last_name = opts[:last_name] || data[:last_name]
        @date_of_birth = opts[:date_of_birth] || opts[:dob] || data[:date_of_birth] || data[:dob]
        @contact_method = opts[:contact_method] || data[:contact_method]
        @contact_value = opts[:contact_value] || data[:contact_value]
        @otp_code = opts[:otp_code] || opts[:otp] || data[:otp_code] || data[:otp]
        @edipi = opts[:edipi] || data[:edipi]
        @veteran_id = opts[:veteran_id] || data[:veteran_id]
        @redis_client = opts[:redis_client] || Vass::RedisClient.build
      end

      ##
      # Validates session parameters for OTP generation.
      #
      # @return [Boolean] true if valid, false otherwise
      #
      def valid_for_creation?
        uuid.present? && last_name.present? && date_of_birth.present?
      end

      ##
      # Validates that the session has required data for OTP validation.
      #
      # @return [Boolean] true if valid, false otherwise
      #
      def valid_for_validation?
        uuid.present? && otp_code.present? && valid_otp_format?
      end

      ##
      # Generates a new 6-digit one-time password (OTP).
      #
      # @return [String] Generated one-time password
      #
      def generate_otp
        SecureRandom.random_number(1_000_000).to_s.rjust(OTP_LENGTH, '0')
      end

      ##
      # Saves the OTP to Redis with expiration.
      # Stores identity data (last_name, dob) for verification during authentication.
      #
      # @param code [String] OTP code to save
      # @return [Boolean] true if saved successfully
      #
      def save_otp(code)
        redis_client.save_otp(uuid:, code:, last_name:, dob: date_of_birth)
      end

      ##
      # Validates the provided OTP and identity against stored values.
      # Ensures the same last_name and dob used during OTP request are provided during authentication.
      #
      # @return [Boolean] true if OTP and identity match, false otherwise
      #
      def valid_otp?
        return false unless valid_for_validation?

        stored_data = redis_client.otp_data(uuid:)
        return false if stored_data.nil?

        # Perform both checks without early returns to prevent timing attacks
        otp_matches = otp_codes_match?(stored_data[:code], otp_code)
        identity_valid = identity_matches?(stored_data)

        otp_matches && identity_valid
      end

      ##
      # Checks if provided identity matches stored identity data.
      # Uses case-insensitive comparison for last name.
      #
      # @param stored_data [Hash] Stored OTP data with :last_name and :dob
      # @return [Boolean] true if identity matches
      #
      def identity_matches?(stored_data)
        stored_last_name = stored_data[:last_name]&.downcase
        stored_dob = stored_data[:dob]

        provided_last_name = last_name&.downcase
        provided_dob = date_of_birth

        stored_last_name == provided_last_name && stored_dob == provided_dob
      end

      ##
      # Checks if OTP has expired (not found in Redis).
      #
      # @return [Boolean] true if OTP is expired/not found
      #
      def otp_expired?
        stored_data = redis_client.otp_data(uuid:)
        stored_data.nil?
      end

      ##
      # Deletes the OTP from Redis after successful validation.
      #
      # @return [void]
      #
      def delete_otp
        redis_client.delete_otp(uuid:)
      end

      ##
      # Generates a session token after successful OTP validation.
      #
      # @return [String] Session token
      #
      def generate_session_token
        SecureRandom.uuid
      end

      ##
      # Returns success response for OTP generation.
      #
      # @return [Hash] Success response data
      #
      def creation_response
        {
          uuid:,
          message: 'OTP generated successfully'
        }
      end

      ##
      # Returns success response for OTP validation.
      #
      # @param session_token [String] Generated session token
      # @return [Hash] Success response data
      #
      def validation_response(session_token:)
        {
          session_token:,
          message: 'OTP validated successfully'
        }
      end

      ##
      # Returns error response for invalid parameters.
      #
      # @return [Hash] Error response data
      #
      def validation_error_response
        {
          error: true,
          message: 'Invalid session parameters'
        }
      end

      ##
      # Returns error response for invalid OTP.
      #
      # @return [Hash] Error response data
      #
      def invalid_otp_response
        {
          error: true,
          message: 'Invalid OTP code'
        }
      end

      ##
      # Sets contact information and veteran data from VASS response.
      #
      # Expects veteran_data to contain 'contact_method' and 'contact_value' keys
      # (extracted by AppointmentsService) along with 'data' key containing veteran info.
      #
      # @param veteran_data [Hash] Veteran data from VASS API with 'data', 'contact_method',
      #   and 'contact_value' keys
      #
      def set_contact_from_veteran_data(veteran_data)
        return unless veteran_data && veteran_data['contact_method'] && veteran_data['contact_value']

        self.contact_method = veteran_data['contact_method']
        self.contact_value = veteran_data['contact_value']
        self.edipi = veteran_data.dig('data', 'edipi')
        self.veteran_id = uuid

        # Store veteran metadata in Redis to avoid fetching again in show flow
        save_veteran_metadata_for_session if edipi.present?
      end

      ##
      # Saves veteran metadata to Redis for later retrieval during session creation.
      #
      # @return [Boolean] true if write succeeds, false otherwise
      #
      def save_veteran_metadata_for_session
        return false unless edipi.present? && uuid.present?

        redis_client.save_veteran_metadata(
          uuid:,
          edipi:,
          veteran_id: uuid
        )
      end

      ##
      # Generates and saves an OTP.
      #
      # @return [String] Generated OTP
      #
      def generate_and_save_otp
        otp_code = generate_otp
        save_otp(otp_code)
        otp_code
      end

      ##
      # Validates OTP, deletes it, and generates a session token.
      #
      # @return [String] Generated session token
      # @raise [Vass::Errors::AuthenticationError] if OTP is invalid
      #
      def validate_and_process_otp
        raise Vass::Errors::AuthenticationError, 'Invalid OTP' unless valid_otp?

        delete_otp
        generate_session_token
      end

      ##
      # Creates an authenticated session after OTP validation.
      #
      # Retrieves veteran metadata from Redis (stored during create flow) and saves it
      # to a session keyed by UUID (one session per veteran). The jti is stored to
      # ensure only the most recently issued token is valid.
      #
      # @param jti [String] JWT ID of the token being issued
      # @return [Boolean] true if session created successfully, false if metadata not found
      #
      def create_authenticated_session(jti:)
        # Retrieve veteran metadata from Redis (stored during create flow)
        metadata = redis_client.veteran_metadata(uuid:)

        unless metadata
          log_vass_event(action: 'metadata_not_found', level: :error)
          return false
        end

        redis_client.save_session(
          uuid:,
          jti:,
          edipi: metadata[:edipi],
          veteran_id: metadata[:veteran_id]
        )
      end

      ##
      # Validates identity against veteran data from VASS.
      #
      # @param veteran_data [Hash] Veteran data from VASS API
      # @raise [Vass::Errors::IdentityValidationError] if identity doesn't match
      #
      def validate_identity_against_veteran_data(veteran_data)
        vass_last_name = veteran_data.dig('data', 'last_name')
        vass_dob = veteran_data.dig('data', 'date_of_birth')

        unless matches_identity?(vass_last_name, vass_dob)
          raise Vass::Errors::IdentityValidationError, 'Identity validation failed'
        end

        true
      end

      ##
      # Validates OTP, deletes it, and generates a JWT token.
      #
      # @return [Hash] Hash containing :token and :jti for audit logging
      # @raise [Vass::Errors::AuthenticationError] if OTP is invalid
      #
      def validate_and_generate_jwt
        raise Vass::Errors::AuthenticationError, 'Invalid OTP' unless valid_otp?

        delete_otp
        generate_jwt_token
      end

      ##
      # Generates a JWT token for authenticated access.
      #
      # @return [Hash] Hash containing :token (JWT string) and :jti (unique JWT ID for audit logging)
      #
      def generate_jwt_token
        jti = SecureRandom.uuid
        payload = {
          sub: uuid,
          jti:,
          iat: Time.now.to_i,
          exp: Time.now.to_i + 3600 # 1 hour expiration
        }

        # Use HS256 signing with shared secret - assumes JWT secret is configured
        token = JWT.encode(payload, jwt_secret, 'HS256')

        { token:, jti: }
      end

      private

      ##
      # Safely compares OTP codes using constant-time comparison.
      # Handles nil, non-string, or unexpected values gracefully.
      #
      # @param stored_code [String, nil] The stored OTP code from cache
      # @param provided_code [String, nil] The user-provided OTP code
      # @return [Boolean] true if codes match, false otherwise
      #
      def otp_codes_match?(stored_code, provided_code)
        return false unless stored_code.is_a?(String) && provided_code.is_a?(String)
        return false if stored_code.empty? || provided_code.empty?

        ActiveSupport::SecurityUtils.secure_compare(stored_code, provided_code)
      end

      ##
      # Checks if submitted identity matches veteran data.
      #
      # @param vass_last_name [String] Last name from VASS
      # @param vass_dob [String] Date of birth from VASS (M/D/YYYY format)
      # @return [Boolean] true if matches
      #
      def matches_identity?(vass_last_name, vass_dob)
        return false if vass_last_name.blank? || vass_dob.blank?

        # Case-insensitive comparison for names
        last_name_matches = vass_last_name.downcase == last_name.downcase

        # Normalize dates to Date objects for comparison
        dob_matches = normalize_date(vass_dob) == normalize_date(date_of_birth)

        last_name_matches && dob_matches
      end

      ##
      # Normalizes a date string to a Date object for comparison.
      #
      # @param date_str [String] Date string in YYYY-MM-DD or M/D/YYYY format
      # @return [Date, nil] Parsed date object or nil if invalid
      #
      def normalize_date(date_str)
        return nil if date_str.blank?

        # VASS returns M/D/YYYY (e.g., "1/15/1990"), user input is YYYY-MM-DD
        if date_str.include?('/')
          parts = date_str.split('/')
          Date.new(parts[2].to_i, parts[0].to_i, parts[1].to_i)
        else
          Date.parse(date_str)
        end
      rescue ArgumentError, TypeError
        nil
      end

      ##
      # Returns JWT secret for token generation.
      #
      # @return [String] JWT secret
      #
      def jwt_secret
        Settings.vass.jwt_secret
      end

      ##
      # Validates contact method is one of the allowed values.
      #
      # @return [Boolean] true if valid
      #
      def valid_contact_method?
        VALID_CONTACT_METHODS.include?(contact_method)
      end

      ##
      # Validates contact value based on contact method.
      #
      # @return [Boolean] true if valid
      #
      def valid_contact_value?
        return false if contact_value.blank?

        case contact_method
        when 'email'
          EMAIL_REGEX.match?(contact_value)
        else
          false
        end
      end

      ##
      # Validates OTP code format (6 digits).
      #
      # @return [Boolean] true if valid format
      #
      def valid_otp_format?
        otp_code.present? && /\A\d{6}\z/.match?(otp_code)
      end
    end
  end
end
