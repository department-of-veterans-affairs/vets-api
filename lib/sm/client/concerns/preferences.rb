# frozen_string_literal: true

module SM
  class Client
    module Preferences
      ##
      # Fetch list of valid email notification frequencies
      # @return [Hash]
      def get_preferences_frequency_list
        perform(:get, 'preferences/notification/list', nil, token_headers).body
      end

      ##
      # Fetch current messaging notification preferences
      # @return [MessagingPreference]
      def get_preferences
        json = perform(:get, 'preferences/notification', nil, token_headers).body
        frequency = MessagingPreference::FREQUENCY_GET_MAP[json[:data][:notify_me]]
        MessagingPreference.new(
          email_address: json[:data][:email_address],
          frequency:
        )
      end

      ##
      # Update messaging notification preferences, returns updated preference object
      # @param params [Hash]
      # @return [MessagingPreference]
      def post_preferences(params)
        mhv_params = MessagingPreference.new(params).mhv_params
        perform(:post, 'preferences/notification', mhv_params, token_headers)
        get_preferences
      end

      ##
      # Fetch current message signature (raw json body)
      # @return [Hash]
      def get_signature
        perform(:get, 'preferences/signature', nil, token_headers).body
      end

      ##
      # Update message signature
      # @param params [Hash]
      # @return [Hash]
      def post_signature(params)
        perform(:post, 'preferences/signature', params.to_h, token_headers).body
      end
    end
  end
end
