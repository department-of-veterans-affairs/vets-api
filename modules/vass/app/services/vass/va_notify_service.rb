# frozen_string_literal: true

module Vass
  ##
  # Service class for sending OTP codes via VANotify.
  #
  # This service handles sending One-Time Passwords (OTP) to users via email
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
    # Sends an OTP code via email.
    #
    # @param contact_method [String] Contact method (must be 'email')
    # @param contact_value [String] Email address
    # @param otp_code [String] OTP code to send
    #
    # @return [VaNotify::NotificationResponse] Response from VANotify
    # @raise [ArgumentError] if contact_method is invalid
    # @raise [VANotify::Error] if VANotify service fails
    #
    def send_otp(contact_method:, contact_value:, otp_code:)
      raise ArgumentError, "Invalid contact_method: #{contact_method}. Must be 'email'" unless contact_method == 'email'

      send_email_otp(contact_value, otp_code)
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
  end
end
