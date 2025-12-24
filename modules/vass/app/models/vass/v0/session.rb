# frozen_string_literal: true

module Vass
  module V0
    ##
    # Session model for managing OTP-based authentication flow.
    #
    # This model handles the generation and validation of One-Time Passcodes (OTP)
    # for non-authenticated users who need to verify their contact information
    # before scheduling appointments.
    #
    # @!attribute uuid
    #   @return [String] Unique session identifier
    # @!attribute contact_method
    #   @return [String] Method of contact (email)
    # @!attribute contact_value
    #   @return [String] Email address or phone number
    # @!attribute otp_code
    #   @return [String] User-provided OTP code for validation
    # @!attribute redis_client
    #   @return [Vass::RedisClient] Redis client for storage operations
    #
    class Session
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
      # @option opts [String] :date_of_birth Veteran's date of birth for validation
      # @option opts [String] :otp_code User-provided OTP for validation
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
      # @option opts [Hash] :data Data hash containing uuid, last_name, date_of_birth
      # @option opts [String] :last_name Veteran's last name
      # @option opts [String] :date_of_birth Veteran's date of birth
      # @option opts [String] :otp_code User-provided OTP for validation
      # @option opts [Vass::RedisClient] :redis_client Optional Redis client
      #
      def initialize(opts = {})
        data = opts[:data] || {}
        @uuid = opts[:uuid] || data[:uuid] || SecureRandom.uuid
        @last_name = opts[:last_name] || data[:last_name]
        @date_of_birth = opts[:date_of_birth] || data[:date_of_birth]
        @contact_method = opts[:contact_method] || data[:contact_method]
        @contact_value = opts[:contact_value] || data[:contact_value]
        @otp_code = opts[:otp_code]
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
      # Generates a new 6-digit OTP code.
      #
      # @return [String] Generated OTP code
      #
      def generate_otp
        SecureRandom.random_number(999_999).to_s.rjust(OTP_LENGTH, '0')
      end

      ##
      # Saves the OTP to Redis with expiration.
      #
      # @param code [String] OTP code to save
      # @return [Boolean] true if saved successfully
      #
      def save_otp(code)
        redis_client.save_otc(uuid:, code:)
      end

      ##
      # Validates the provided OTP against the stored value.
      #
      # @return [Boolean] true if OTP matches, false otherwise
      #
      def valid_otp?
        return false unless valid_for_validation?

        stored_otp = redis_client.otc(uuid:)
        return false if stored_otp.nil?

        # Constant-time comparison to prevent timing attacks
        ActiveSupport::SecurityUtils.secure_compare(stored_otp, otp_code)
      end

      ##
      # Deletes the OTP from Redis after successful validation.
      #
      # @return [void]
      #
      def delete_otp
        redis_client.delete_otc(uuid:)
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
      # Generates and saves an OTP code.
      #
      # @return [String] Generated OTP code
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
      # to a session keyed by the session token.
      #
      # @param session_token [String] Generated session token
      # @return [Boolean] true if session created successfully, false if metadata not found
      #
      def create_authenticated_session(session_token:)
        # Retrieve veteran metadata from Redis (stored during create flow)
        metadata = redis_client.veteran_metadata(uuid:)

        return false unless metadata

        redis_client.save_session(
          session_token:,
          edipi: metadata[:edipi],
          veteran_id: metadata[:veteran_id],
          uuid:
        )
      end

      private

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
