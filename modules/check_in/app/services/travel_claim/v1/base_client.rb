# frozen_string_literal: true

module TravelClaim
  module V1
    ##
    # Base client class for V1 Travel Claim API interactions.
    #
    # Inherits from Common::Client::Base for circuit breaker protection, error handling,
    # and Datadog tracing. Includes monitoring for StatsD metrics. Provides shared
    # subscription key validation and header building for all V1 clients.
    #
    class BaseClient < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = 'api.check_in.travel_claim'

      ##
      # Returns the singleton configuration instance for Travel Claim services.
      #
      # @return [TravelClaim::Configuration] The configuration instance
      #
      def config
        TravelClaim::Configuration.instance
      end

      private

      ##
      # Validates and loads subscription keys at initialization.
      # Fails fast if required keys are missing.
      #
      # @raise [RuntimeError] if required subscription keys are not configured
      #
      def validate_subscription_keys!
        settings = Settings.check_in.travel_reimbursement_api_v2

        if Settings.vsp_environment == 'production'
          @subscription_key_e = require_setting(settings, :e_subscription_key)
          @subscription_key_s = require_setting(settings, :s_subscription_key)
        else
          @subscription_key = require_setting(settings, :subscription_key)
        end
      end

      ##
      # Builds environment-specific subscription key headers for API authentication.
      # Production uses separate E and S subscription keys, while other environments
      # use a single subscription key.
      #
      # @return [Hash] Headers hash with appropriate subscription keys
      #
      def subscription_key_headers
        if Settings.vsp_environment == 'production'
          {
            'Ocp-Apim-Subscription-Key-E' => @subscription_key_e,
            'Ocp-Apim-Subscription-Key-S' => @subscription_key_s
          }
        else
          { 'Ocp-Apim-Subscription-Key' => @subscription_key }
        end
      end

      ##
      # Validates that a required setting is present and returns its string value.
      #
      # @param settings [Config::Options] The settings object
      # @param key [Symbol] The setting key to validate
      # @return [String] The setting value as a string
      # @raise [RuntimeError] if the setting is missing or blank
      #
      def require_setting(settings, key)
        settings.public_send(key).to_s.presence || raise("Missing required setting: #{key}")
      end

      ##
      # Determines if mock responses should be used for API calls.
      # Checks both configuration setting and feature flag.
      #
      # @return [Boolean] true if mocking is enabled
      #
      def mock_enabled?
        Settings.check_in.travel_reimbursement_api_v2.mock ||
          Flipper.enabled?('check_in_experience_mock_enabled')
      end
    end
  end
end
