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
    #   @return [String] Method of contact (email or sms)
    # @!attribute contact_value
    #   @return [String] Email address or phone number
    # @!attribute otp_code
    #   @return [String] User-provided OTP code for validation
    # @!attribute redis_client
    #   @return [Vass::RedisClient] Redis client for storage operations
    #
    class Session
      # Valid contact methods for OTP delivery
      VALID_CONTACT_METHODS = %w[email sms].freeze

      # Email validation regex (basic RFC 5322 compliant)
      EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

      # Phone number validation regex (10-11 digits, optional +1 prefix)
      PHONE_REGEX = /\A(\+?1)?[0-9]{10}\z/

      # OTP code length
      OTP_LENGTH = 6

      attr_reader :uuid, :contact_method, :contact_value, :otp_code, :redis_client

      ##
      # Builds a Session instance.
      #
      # @param opts [Hash] Options to create the session
      # @option opts [String] :uuid Session UUID
      # @option opts [String] :contact_method Contact method (email/sms)
      # @option opts [String] :contact_value Email or phone number
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
      # @option opts [String] :uuid Session UUID
      # @option opts [Hash] :data Data hash containing contact_method and contact_value
      # @option opts [String] :contact_method Contact method (email/sms)
      # @option opts [String] :contact_value Email or phone number
      # @option opts [String] :otp_code User-provided OTP for validation
      # @option opts [Vass::RedisClient] :redis_client Optional Redis client
      #
      def initialize(opts = {})
        data = opts[:data] || {}
        @uuid = opts.key?(:uuid) ? opts[:uuid] : SecureRandom.uuid
        @contact_method = opts[:contact_method] || data[:contact_method]
        @contact_value = opts[:contact_value] || data[:contact_value]
        @otp_code = opts[:otp_code]
        @redis_client = opts[:redis_client] || Vass::RedisClient.build
      end

      ##
      # Validates session parameters for OTP generation.
      #
      # @return [Boolean] true if valid, false otherwise
      #
      def valid_for_creation?
        valid_contact_method? && valid_contact_value?
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
        when 'sms'
          normalized_phone = contact_value.gsub(/\D/, '')
          PHONE_REGEX.match?(normalized_phone)
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
