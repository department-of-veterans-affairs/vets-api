# frozen_string_literal: true

require 'benefits_claims/concerns/multi_provider_base'

# Web-specific implementation of multi-provider support for BenefitsClaimsController.
# Extends the shared BenefitsClaims::Concerns::MultiProviderBase with web-specific
# response formatting and metrics.
#
# Note: This concern references BenefitsClaimsController's STATSD_METRIC_PREFIX and
# STATSD_TAGS constants for metrics reporting. This coupling is intentional.
module V0
  module Concerns
    module MultiProviderSupport
      extend ActiveSupport::Concern
      include BenefitsClaims::Concerns::MultiProviderBase

      private

      def format_error_entry(provider_name, message)
        { 'provider' => provider_name, 'error' => message }
      end

      def format_get_claims_response(claims_data, errors)
        { 'data' => claims_data, 'meta' => { 'provider_errors' => errors.presence }.compact }
      end

      def statsd_metric_name(action)
        controller_class = self.class
        "#{controller_class::STATSD_METRIC_PREFIX}.#{action}"
      end

      def statsd_tags_for_provider(provider_name)
        controller_class = self.class
        controller_class::STATSD_TAGS + ["provider:#{provider_name}"]
      end

      # Overrides base implementation to use explicit routing instead of fallback iteration.
      #
      # Retrieves a claim from the appropriate provider based on provider_type parameter.
      #
      # The type parameter is optional and defaults to lighthouse for backward compatibility
      # with existing bookmarks/URLs. This means lighthouse claims can be accessed without
      # specifying type, even when multiple providers exist. Other providers require the
      # type parameter to be explicitly specified.
      #
      # For Lighthouse claims, routes through V0::LighthouseClaims::Proxy to apply
      # web-specific transforms. Other providers use their provider implementation directly.
      #
      # Rollout strategy: Frontend will deploy first to send type parameter, then we enable
      # the second provider. This ensures type is always present before it becomes required.
      def get_claim_from_providers(claim_id, provider_type = nil)
        # If provider_type is specified, route based on type
        return get_claim_for_provider_type(claim_id, provider_type) if provider_type.present?

        # No provider_type specified - default to lighthouse for backward compatibility
        lighthouse_proxy.get_claim(claim_id)
      end

      # Routes claim request to appropriate implementation based on provider type
      # Lighthouse uses Proxy (with web-specific transforms), others use provider directly
      def get_claim_for_provider_type(claim_id, provider_type)
        provider_class = provider_class_for_type(provider_type)

        if lighthouse_provider?(provider_class)
          lighthouse_proxy.get_claim(claim_id)
        else
          provider = provider_class.new(@current_user)
          provider.get_claim(claim_id)
        end
      end

      # Checks if a provider class is the Lighthouse provider
      def lighthouse_provider?(provider_class)
        provider_class.name.downcase.include?('lighthouse')
      end

      # Returns the web-specific Lighthouse Proxy
      # This proxy includes web transforms (rename_rv1, suppress_evidence_requests)
      def lighthouse_proxy
        @lighthouse_proxy ||= V0::LighthouseClaims::Proxy.new(@current_user)
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
