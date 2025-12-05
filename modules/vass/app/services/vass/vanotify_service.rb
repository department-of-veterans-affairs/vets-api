# frozen_string_literal: true

module Vass
  ##
  # Service class for sending OTP codes via VANotify.
  #
  # This service handles sending One-Time Passcodes (OTP) to users via email or SMS
  # using the VANotify service.
  #
  # @example Send OTP via email
  #   service = Vass::VANotifyService.build
  #   service.send_otp(
  #     contact_method: 'email',
  #     contact_value: 'veteran@example.com',
  #     otp_code: '123456'
  #   )
  #
  # @example Send OTP via SMS
  #   service = Vass::VANotifyService.build
  #   service.send_otp(
  #     contact_method: 'sms',
  #     contact_value: '5555551234',
  #     otp_code: '123456'
  #   )
  #
  class VANotifyService
    attr_reader :notify_client, :api_key

    ##
    # Builds a VANotifyService instance.
    #
    # @param opts [Hash] Options to create the service
    # @option opts [String] :api_key VANotify API key (optional, defaults to va_gov)
    #
    # @return [Vass::VANotifyService] An instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    ##
    # Initializes a new VANotifyService.
    #
    # @param opts [Hash] Options to create the service
    # @option opts [String] :api_key VANotify API key (optional, defaults to va_gov)
    #
    def initialize(opts = {})
      @api_key = opts[:api_key] || default_api_key
      @notify_client = VaNotify::Service.new(@api_key)
    end

    ##
    # Sends an OTP code via the specified contact method.
    #
    # @param contact_method [String] Contact method ('email' or 'sms')
    # @param contact_value [String] Email address or phone number
    # @param otp_code [String] OTP code to send
    #
    # @return [VaNotify::NotificationResponse] Response from VANotify
    # @raise [ArgumentError] if contact_method is invalid
    # @raise [VANotify::Error] if VANotify service fails
    #
    def send_otp(contact_method:, contact_value:, otp_code:)
      case contact_method
      when 'email'
        send_email_otp(contact_value, otp_code)
      when 'sms'
        send_sms_otp(contact_value, otp_code)
      else
        raise ArgumentError, "Invalid contact_method: #{contact_method}. Must be 'email' or 'sms'"
      end
    end

    private

    ##
    # Sends OTP via email.
    #
    # @param email_address [String] Email address
    # @param otp_code [String] OTP code
    #
    # @return [VaNotify::NotificationResponse] Response from VANotify
    #
    def send_email_otp(email_address, otp_code)
      notify_client.send_email(
        email_address:,
        template_id: email_template_id,
        personalisation: { otp_code: }
      )
    end

    ##
    # Sends OTP via SMS.
    #
    # @param phone_number [String] Phone number
    # @param otp_code [String] OTP code
    #
    # @return [VaNotify::NotificationResponse] Response from VANotify
    #
    def send_sms_otp(phone_number, otp_code)
      # Normalize phone number (remove non-digits, ensure +1 prefix if needed)
      normalized_phone = normalize_phone_number(phone_number)

      notify_client.send_sms(
        phone_number: normalized_phone,
        template_id: sms_template_id,
        personalisation: { otp_code: }
      )
    end

    ##
    # Normalizes phone number for SMS delivery.
    #
    # @param phone_number [String] Phone number to normalize
    #
    # @return [String] Normalized phone number
    #
    def normalize_phone_number(phone_number)
      # Remove all non-digit characters
      digits = phone_number.gsub(/\D/, '')

      # If 10 digits, add +1 prefix; if 11 digits starting with 1, add + prefix
      if digits.length == 10
        "+1#{digits}"
      elsif digits.length == 11 && digits.start_with?('1')
        "+#{digits}"
      else
        phone_number
      end
    end

    ##
    # Returns the default API key from settings.
    #
    # @return [String] API key
    #
    def default_api_key
      Settings.vanotify.services.va_gov.api_key
    end

    ##
    # Returns the email template ID for OTP.
    #
    # @return [String] Template ID
    #
    def email_template_id
      Settings.vanotify.services.va_gov.template_id.vass_otp_email ||
        raise(ArgumentError, 'VASS OTP email template ID not configured')
    end

    ##
    # Returns the SMS template ID for OTP.
    #
    # @return [String] Template ID
    #
    def sms_template_id
      Settings.vanotify.services.va_gov.template_id.vass_otp_sms ||
        raise(ArgumentError, 'VASS OTP SMS template ID not configured')
    end
  end
end
