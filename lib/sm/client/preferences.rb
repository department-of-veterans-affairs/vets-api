# frozen_string_literal: true

module SM
  class Client < Common::Client::Base
    ##
    # Module containing preference-related methods for the SM Client
    #
    module Preferences
      ##
      # Fetch the list of available constant values for email frequency
      #
      # @return [Hash] an object containing the body of the response
      #
      def get_preferences_frequency_list
        perform(:get, 'preferences/notification/list', nil, token_headers).body
      end

      ##
      # Fetch the current email settings, including address and frequency
      #
      # @return [MessagingPreference]
      #
      def get_preferences
        json = perform(:get, 'preferences/notification', nil, token_headers).body
        frequency = MessagingPreference::FREQUENCY_GET_MAP[json[:data][:notify_me]]
        MessagingPreference.new(email_address: json[:data][:email_address],
                                frequency:)
      end

      ##
      # Set the email address and frequency for getting emails.
      #
      # @param params [Hash] a hash of parameter objects
      # @example
      #   client.post_preferences(email_address: 'name@example.com', frequency: 'daily')
      # @return [MessagingPreference]
      # @raise [Common::Exceptions::ValidationErrors] if the email address is invalid
      # @raise [Common::Exceptions::BackendServiceException] if unhandled validation error is encountered in
      #   email_address, as mapped to SM152 code in config/locales/exceptions.en.yml
      #
      def post_preferences(params)
        mhv_params = MessagingPreference.new(params).mhv_params
        perform(:post, 'preferences/notification', mhv_params, token_headers)
        get_preferences
      end

      ##
      # Fetch current message signature
      #
      # @return [String] json response
      #
      def get_signature
        perform(:get, 'preferences/signature', nil, token_headers).body
      end

      ##
      # Update current message signature
      #
      # @return [String] json response
      #
      def post_signature(params)
        request_body = MessagingSignature.new(params).to_h
        perform(:post, 'preferences/signature', request_body, token_headers).body
      end
    end
  end
end
