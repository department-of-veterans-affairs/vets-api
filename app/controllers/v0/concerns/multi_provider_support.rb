# frozen_string_literal: true

# This concern extracts multi-provider aggregation methods from BenefitsClaimsController
# to satisfy Metrics/ClassLength linting requirements.
#
# Note: This concern is tightly coupled to BenefitsClaimsController and references its
# STATSD_METRIC_PREFIX and STATSD_TAGS constants. This coupling is intentional as the
# concern is not designed for reuse in other controllers.
module V0
  module Concerns
    module MultiProviderSupport
      extend ActiveSupport::Concern

      private

      def configured_providers
        BenefitsClaims::Providers::ProviderRegistry.enabled_provider_classes(@current_user)
      end

      def get_claims_from_providers
        claims_data = []
        provider_errors = []
        configured_providers.each do |provider_class|
          provider = provider_class.new(@current_user)
          response = provider.get_claims
          claims_data.concat(extract_claims_data(provider_class, response))
        rescue Common::Exceptions::Unauthorized,
               Common::Exceptions::Forbidden => e
          # Re-raise: these are user-level auth errors that affect ALL providers
          raise e
        rescue => e
          # Handle all other errors, log and try next provider
          handle_provider_error(provider_class, e, provider_errors)
        end
        { 'data' => claims_data, 'meta' => { 'provider_errors' => provider_errors.presence }.compact }
      end

      def extract_claims_data(provider_class, response)
        provider_name = provider_class.name
        logger = ::Rails.logger

        if response.nil?
          logger.warn("Provider #{provider_name} returned nil from get_claims")
          return []
        end

        is_hash = response.is_a?(Hash)
        has_data_key = is_hash && response.key?('data')

        unless has_data_key
          logger.error(
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

      def handle_provider_error(provider_class, error, provider_errors)
        provider_name = provider_class.name
        controller_class = self.class

        provider_errors << { 'provider' => provider_name, 'error' => 'Provider temporarily unavailable' }

        ::Rails.logger.warn(
          "Provider #{provider_name} failed",
          { provider: provider_name, error_class: error.class.name }
        )
        StatsD.increment("#{controller_class::STATSD_METRIC_PREFIX}.provider_error",
                         tags: controller_class::STATSD_TAGS + ["provider:#{provider_name}"])
      end

      # Retrieves a claim from the appropriate provider based on provider_type parameter.
      #
      # When multiple providers exist, the type parameter is REQUIRED to prevent ID collision
      # (same claim ID could exist in multiple systems). With a single provider, type is optional
      # for backward compatibility.
      #
      # Rollout strategy: Frontend will deploy first to send type parameter, then we enable
      # the second provider. This ensures type is always present before it becomes required.
      def get_claim_from_providers(claim_id, provider_type = nil)
        # If provider_type is specified, use it directly
        if provider_type.present?
          provider_class = provider_class_for_type(provider_type)
          provider = provider_class.new(@current_user)
          return provider.get_claim(claim_id)
        end

        # No provider_type specified - check if multiple providers exist
        if configured_providers.length > 1
          valid_types = supported_provider_types.join(', ')
          detail_message = "Provider type is required. Valid types: #{valid_types}"
          raise Common::Exceptions::ParameterMissing.new('type', detail: detail_message)
        end

        # Single provider - no id collision possible
        provider_class = configured_providers.first
        provider = provider_class.new(@current_user)
        provider.get_claim(claim_id)
      end

      def provider_class_for_type(type)
        case type.to_s.downcase
        when 'lighthouse'
          BenefitsClaims::Providers::Lighthouse::LighthouseBenefitsClaimsProvider
        # TODO: Add ID collision test when multiple providers are available
        else
          raise Common::Exceptions::ParameterMissing.new('type', detail: "Unknown provider type: #{type}")
        end
      end

      def supported_provider_types
        # Returns list of valid provider type strings that can be used in the type parameter
        # This is derived from the provider_class_for_type case statement
        ['lighthouse']
      end
    end
  end
end
