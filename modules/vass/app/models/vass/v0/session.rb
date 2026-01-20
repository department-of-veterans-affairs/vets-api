# frozen_string_literal: true

module Vass
  module V0
    ##
    # Session model for managing OTC-based authentication flow.
    #
    # This model handles the generation and validation of One-Time Codes (OTC)
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
    #   @return [String] User-provided one-time code (OTC) for validation (aliased as otc)
    # @!attribute redis_client
    #   @return [Vass::RedisClient] Redis client for storage operations
    #
    class Session
      # Valid contact methods for OTC delivery
      VALID_CONTACT_METHODS = %w[email].freeze

      # Email validation regex (basic RFC 5322 compliant)
      EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

      # OTC code length
      OTC_LENGTH = 6
      OTP_LENGTH = 6 # Alias for backwards compatibility

      attr_accessor :contact_method, :contact_value, :edipi, :veteran_id
      attr_reader :uuid, :last_name, :date_of_birth, :otp_code, :redis_client

      ##
      # Builds a Session instance.
      #
      # @param opts [Hash] Options to create the session
      # @option opts [String] :uuid Veteran UUID (veteran_id from welcome email)
      # @option opts [String] :last_name Veteran's last name for validation
      # @option opts [String] :dob Veteran's date of birth for validation (YYYY-MM-DD)
      # @option opts [String] :otc User-provided OTC for validation
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
      # @option opts [String] :otc User-provided OTC for validation
      # @option opts [String] :otp_code User-provided OTP for validation - alias for otc
      # @option opts [Vass::RedisClient] :redis_client Optional Redis client
      #
      def initialize(opts = {})
        data = opts[:data] || {}
        @uuid = opts[:uuid] || data[:uuid] || SecureRandom.uuid
        @last_name = opts[:last_name] || data[:last_name]
        @date_of_birth = opts[:date_of_birth] || opts[:dob] || data[:date_of_birth] || data[:dob]
        @contact_method = opts[:contact_method] || data[:contact_method]
        @contact_value = opts[:contact_value] || data[:contact_value]
        @otp_code = opts[:otp_code] || opts[:otc] || data[:otp_code] || data[:otc]
        @edipi = opts[:edipi] || data[:edipi]
        @veteran_id = opts[:veteran_id] || data[:veteran_id]
        @redis_client = opts[:redis_client] || Vass::RedisClient.build
      end

      ##
      # Validates session parameters for OTC generation.
      #
      # @return [Boolean] true if valid, false otherwise
      #
      def valid_for_creation?
        uuid.present? && last_name.present? && date_of_birth.present?
      end

      ##
      # Validates that the session has required data for OTC validation.
      #
      # @return [Boolean] true if valid, false otherwise
      #
      def valid_for_validation?
        uuid.present? && otp_code.present? && valid_otc_format?
      end

      ##
      # Generates a new 6-digit one-time code (OTC).
      #
      # @return [String] Generated one-time code
      #
      def generate_otc
        SecureRandom.random_number(1_000_000).to_s.rjust(OTC_LENGTH, '0')
      end

      ##
      # Saves the OTC to Redis with expiration.
      #
      # @param code [String] OTC code to save
      # @return [Boolean] true if saved successfully
      #
      def save_otc(code)
        redis_client.save_otc(uuid:, code:)
      end

      ##
      # Validates the provided OTC against the stored value.
      #
      # @return [Boolean] true if OTC matches, false otherwise
      #
      def valid_otc?
        return false unless valid_for_validation?

        stored_otc = redis_client.otc(uuid:)
        return false if stored_otc.nil?

        # Constant-time comparison to prevent timing attacks
        ActiveSupport::SecurityUtils.secure_compare(stored_otc, otp_code)
      end

      ##
      # Checks if OTC has expired (not found in Redis).
      #
      # @return [Boolean] true if OTC is expired/not found
      #
      def otc_expired?
        stored_otc = redis_client.otc(uuid:)
        stored_otc.nil?
      end

      ##
      # Deletes the OTC from Redis after successful validation.
      #
      # @return [void]
      #
      def delete_otc
        redis_client.delete_otc(uuid:)
      end

      ##
      # Generates a session token after successful OTC validation.
      #
      # @return [String] Session token
      #
      def generate_session_token
        SecureRandom.uuid
      end

      ##
      # Returns success response for OTC generation.
      #
      # @return [Hash] Success response data
      #
      def creation_response
        {
          uuid:,
          message: 'OTC generated successfully'
        }
      end

      ##
      # Returns success response for OTC validation.
      #
      # @param session_token [String] Generated session token
      # @return [Hash] Success response data
      #
      def validation_response(session_token:)
        {
          session_token:,
          message: 'OTC validated successfully'
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
      # Returns error response for invalid OTC.
      #
      # @return [Hash] Error response data
      #
      def invalid_otc_response
        {
          error: true,
          message: 'Invalid OTC code'
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
      # Generates and saves an OTC.
      #
      # @return [String] Generated OTC
      #
      def generate_and_save_otc
        otc_code = generate_otc
        save_otc(otc_code)
        otc_code
      end

      ##
      # Validates OTC, deletes it, and generates a session token.
      #
      # @return [String] Generated session token
      # @raise [Vass::Errors::AuthenticationError] if OTC is invalid
      #
      def validate_and_process_otc
        raise Vass::Errors::AuthenticationError, 'Invalid OTC' unless valid_otc?

        delete_otc
        generate_session_token
      end

      ##
      # Creates an authenticated session after OTC validation.
      #
      # Retrieves veteran metadata from Redis (stored during create flow) and saves it
      # to a session keyed by the token.
      #
      # @param token [String] Generated JWT token
      # @param session_token [String] Deprecated: use token instead
      # @return [Boolean] true if session created successfully, false if metadata not found
      #
      def create_authenticated_session(token: nil, session_token: nil)
        # Support both token and session_token for backwards compatibility
        auth_token = token || session_token

        # Retrieve veteran metadata from Redis (stored during create flow)
        metadata = redis_client.veteran_metadata(uuid:)

        return false unless metadata

        redis_client.save_session(
          session_token: auth_token,
          edipi: metadata[:edipi],
          veteran_id: metadata[:veteran_id],
          uuid:
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
      # Validates OTC, deletes it, and generates a JWT token.
      #
      # @return [String] Generated JWT token
      # @raise [Vass::Errors::AuthenticationError] if OTC is invalid
      #
      def validate_and_generate_jwt
        raise Vass::Errors::AuthenticationError, 'Invalid OTC' unless valid_otc?

        delete_otc
        generate_jwt_token
      end

      ##
      # Generates a JWT token for authenticated access.
      #
      # @return [String] JWT token
      #
      def generate_jwt_token
        payload = {
          sub: uuid,
          jti: SecureRandom.uuid,
          iat: Time.now.to_i,
          exp: Time.now.to_i + 3600 # 1 hour expiration
        }

        # Use HS256 signing with shared secret - assumes JWT secret is configured
        JWT.encode(payload, jwt_secret, 'HS256')
      end

      private

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
      # Validates OTC code format (6 digits).
      #
      # @return [Boolean] true if valid format
      #
      def valid_otc_format?
        otp_code.present? && /\A\d{6}\z/.match?(otp_code)
      end
    end
  end
end
