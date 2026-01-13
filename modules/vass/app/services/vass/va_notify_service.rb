# frozen_string_literal: true

module Vass
  ##
  # Service class for sending OTC codes via VANotify.
  #
  # This service handles sending One-Time Codes (OTC) to users via email
  # using the VANotify service.
  #
  # @example Send OTC via email
  #   service = Vass::VANotifyService.build
  #   service.send_otc(
  #     contact_method: 'email',
  #     contact_value: 'veteran@example.com',
  #     otc_code: '123456'
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
    # Sends an OTC code via email.
    #
    # @param contact_method [String] Contact method (must be 'email')
    # @param contact_value [String] Email address
    # @param otc_code [String] OTC code to send
    #
    # @return [VaNotify::NotificationResponse] Response from VANotify
    # @raise [ArgumentError] if contact_method is invalid
    # @raise [VANotify::Error] if VANotify service fails
    #
    def send_otc(contact_method:, contact_value:, otc_code:)
      raise ArgumentError, "Invalid contact_method: #{contact_method}. Must be 'email'" unless contact_method == 'email'

      send_email_otc(contact_value, otc_code)
    end

    private

    ##
    # Sends OTC via email.
    #
    # @param email_address [String] Email address
    # @param otc_code [String] OTC code
    #
    # @return [VaNotify::NotificationResponse] Response from VANotify
    #
    def send_email_otc(email_address, otc_code)
      notify_client.send_email(
        email_address:,
        template_id: email_template_id,
        personalisation: { otc_code: }
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
    # Returns the email template ID for OTC.
    #
    # @return [String] Template ID
    #
    def email_template_id
      Settings.vanotify.services.va_gov.template_id.vass_otp_email ||
        raise(ArgumentError, 'VASS OTC email template ID not configured')
    end
  end
end
