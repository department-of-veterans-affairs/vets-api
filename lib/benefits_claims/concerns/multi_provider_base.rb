# frozen_string_literal: true

# Base module providing shared multi-provider aggregation logic for claims.
# Implements the template method pattern to allow web and mobile concerns to
# customize error formatting, response structure, and metrics while sharing
# the core iteration and validation logic.
#
# Subclasses must implement:
# - format_error_entry(provider_name, message)
# - format_get_claims_response(claims_data, errors)
# - statsd_metric_name(action)
# - statsd_tags_for_provider(provider_name)
module BenefitsClaims
  module Concerns
    module MultiProviderBase
      extend ActiveSupport::Concern

      private

      # Returns enabled provider classes from the registry
      def configured_providers
        BenefitsClaims::Providers::ProviderRegistry.enabled_provider_classes(@current_user)
      end

      # Fetches claims from all enabled providers
      # Subclasses customize the return format via format_get_claims_response
      def get_claims_from_providers
        claims_data = []
        errors = []

        configured_providers.each do |provider_class|
          provider = provider_class.new(@current_user)
          response = provider.get_claims
          claims_data.concat(extract_claims_data(provider_class, response))
        rescue Common::Exceptions::Unauthorized,
               Common::Exceptions::Forbidden => e
          # Re-raise: these are user-level auth errors that affect ALL providers
          raise e
        rescue => e
          # Handle provider-specific errors: log and continue to next provider
          handle_provider_error(provider_class, e, errors)
        end

        format_get_claims_response(claims_data, errors)
      end

      # Extracts and validates claims data from provider response
      def extract_claims_data(provider_class, response)
        provider_name = provider_class.name

        if response.nil?
          Rails.logger.warn("Provider #{provider_name} returned nil from get_claims")
          return []
        end

        unless response.is_a?(Hash) && response.key?('data')
          Rails.logger.error(
            "Provider #{provider_name} returned unexpected structure from get_claims",
            {
              provider: provider_name,
              response_class: response.class.name
            }
          )
          return []
        end

        response['data'] || []
      end

      # Handles provider errors: formats error, logs, and tracks metrics
      def handle_provider_error(provider_class, error, errors)
        provider_name = provider_class.name

        # Add error using subclass-specific format
        errors << format_error_entry(provider_name, "Provider #{provider_name} temporarily unavailable")

        Rails.logger.warn(
          "Provider #{provider_name} failed to fetch claims",
          {
            provider: provider_name,
            error_class: error.class.name,
            error_message: error.message
          }
        )

        StatsD.increment(
          statsd_metric_name('provider_error'),
          tags: statsd_tags_for_provider(provider_name)
        )
      end

      # Fetches a single claim from providers by trying each until found
      def get_claim_from_providers(claim_id)
        configured_providers.each do |provider_class|
          provider = provider_class.new(@current_user)
          response = provider.get_claim(claim_id)
          return response if validate_claim_response(response)
        rescue Common::Exceptions::RecordNotFound
          # Expected: this provider doesn't have the claim, try next provider
          log_claim_not_found(provider_class, claim_id)
        rescue Common::Exceptions::Unauthorized,
               Common::Exceptions::Forbidden => e
          # Re-raise: these are user-level auth errors that affect ALL providers
          raise e
        rescue => e
          # Unexpected error: log and try next provider
          handle_get_claim_error(provider_class, claim_id, e)
        end

        raise Common::Exceptions::RecordNotFound, claim_id
      end

      # Validates that a claim response has the expected structure
      # Can be overridden by subclasses for stricter validation
      def validate_claim_response(response)
        response && response['data']
      end

      def log_claim_not_found(provider_class, claim_id)
        Rails.logger.info(
          "Provider #{provider_class.name} doesn't have claim #{claim_id}",
          { provider: provider_class.name, claim_id: }
        )
      end

      def handle_get_claim_error(provider_class, claim_id, error)
        provider_name = provider_class.name

        Rails.logger.error(
          "Provider #{provider_name} error fetching claim #{claim_id}",
          {
            provider: provider_name,
            claim_id:,
            error_class: error.class.name,
            error_message: error.message
          }
        )

        StatsD.increment(
          statsd_metric_name('get_claim.provider_error'),
          tags: statsd_tags_for_provider(provider_name)
        )
      end

      # Template methods - must be implemented by including modules

      # Formats an error entry for the provider error list
      # @param provider_name [String] The provider name
      # @param message [String] The error message
      # @return [Hash] Formatted error entry
      def format_error_entry(_provider_name, _message)
        raise NotImplementedError, 'Subclasses must implement format_error_entry'
      end

      # Formats the final response from get_claims_from_providers
      # @param claims_data [Array] Array of claim hashes
      # @param errors [Array] Array of error entries
      # @return [Object] Formatted response (Hash for web, Array for mobile)
      def format_get_claims_response(_claims_data, _errors)
        raise NotImplementedError, 'Subclasses must implement format_get_claims_response'
      end

      # Returns the StatsD metric name for the given action
      # @param action [String] The action being tracked (e.g., 'provider_error')
      # @return [String] Full metric name
      def statsd_metric_name(_action)
        raise NotImplementedError, 'Subclasses must implement statsd_metric_name'
      end

      # Returns StatsD tags for the provider
      # @param provider_name [String] The provider name
      # @return [Array<String>] Array of tag strings
      def statsd_tags_for_provider(_provider_name)
        raise NotImplementedError, 'Subclasses must implement statsd_tags_for_provider'
      end
    end
  end
end
