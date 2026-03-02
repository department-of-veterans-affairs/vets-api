# frozen_string_literal: true

require 'benefits_claims/concerns/multi_provider_base'

# This concern provides multi-claim provider support for the mobile ClaimsAndAppealsController.
# It fetches claims from all enabled providers in the BenefitsClaims::Providers::ProviderRegistry
# and returns them in a format compatible with mobile's existing adapter and error handling.
#
# Unlike the web version (V0::Concerns::MultiProviderSupport), this concern:
# - Returns raw claims data that will be parsed by Mobile::V0::Adapters::ClaimsOverview
# - Uses mobile's error format: [{ service: 'provider_name', error_details: 'message' }]
# - Integrates with mobile's existing claims/appeals aggregation pattern
module Mobile
  module V0
    module Concerns
      module MultiProviderSupport
        extend ActiveSupport::Concern
        include BenefitsClaims::Concerns::MultiProviderBase

        private

        def format_error_entry(provider_name, message)
          {
            service: provider_name,
            error_details: message
          }
        end

        def format_get_claims_response(claims_data, errors)
          [claims_data, errors]
        end

        def statsd_metric_name(action)
          "mobile.claims_and_appeals.#{action}"
        end

        def statsd_tags_for_provider(provider_name)
          ["provider:#{provider_name}"]
        end

        # Overrides base implementation to use explicit routing instead of fallback iteration.
        #
        # Retrieves a claim from the appropriate provider based on provider_type parameter.
        #
        # The type parameter is optional and defaults to lighthouse for backward compatibility
        # with existing bookmarked URLs. This means lighthouse claims can be accessed without
        # specifying type, even when multiple providers exist. Other providers require the
        # type parameter to be explicitly specified to prevent ID collisions.
        #
        # For Lighthouse claims, routes through Mobile::V0::LighthouseClaims::Proxy to apply
        # mobile-specific transforms. Other providers use their provider implementation directly.

        def get_claim_from_providers(claim_id, provider_type = nil)
          # If provider_type is specified, route based on type
          return get_claim_for_provider_type(claim_id, provider_type) if provider_type.present?

          # Default to lighthouse if no type parameter is specified
          lighthouse_proxy.get_claim(claim_id)
        end

        # Routes claim request to appropriate implementation based on provider type
        # Lighthouse uses Proxy (with mobile-specific transforms), others use provider directly
        def get_claim_for_provider_type(claim_id, provider_type)
          provider_class = provider_class_for_type(provider_type)

          if lighthouse_provider?(provider_class)
            lighthouse_proxy.get_claim(claim_id)
          else
            provider = provider_class.new(@current_user)
            provider.get_claim(claim_id)
          end
        end

        # Maps provider type strings to their provider classes
        # Single source of truth for supported providers
        PROVIDER_TYPE_MAPPINGS = {
          'lighthouse' => BenefitsClaims::Providers::Lighthouse::LighthouseBenefitsClaimsProvider
          # TODO: Add CHAMPVA mapping when provider is onboarded to CST
          # 'champva' => BenefitsClaims::Providers::Champva::ChampvaBenefitsClaimsProvider
        }.freeze

        def provider_class_for_type(type)
          normalized_type = type.to_s.downcase
          provider_class = PROVIDER_TYPE_MAPPINGS[normalized_type]

          if provider_class.nil?
            raise Common::Exceptions::InvalidFieldValue.new('type', type)
          end

          provider_class
        end

        def supported_provider_types
          PROVIDER_TYPE_MAPPINGS.keys
        end

        # Override base implementation to add provider field to each claim
        def extract_claims_data(provider_class, response)
          claims_data = super(provider_class, response)
          provider_type = provider_type_from_class(provider_class)

          # Add provider field to each claim
          claims_data.each do |claim|
            claim['provider'] = provider_type if claim.is_a?(Hash)
          end

          claims_data
        end

        # Maps provider class to provider type string
        def provider_type_from_class(provider_class)
          # Reverse lookup from PROVIDER_TYPE_MAPPINGS
          PROVIDER_TYPE_MAPPINGS.each do |type, klass|
            return type if klass == provider_class
          end

          # Fallback: derive from class name for testing/unknown providers
          class_name = provider_class.name.to_s.downcase
          return 'lighthouse' if class_name.include?('lighthouse')

          # return 'champva' if class_name.include?('champva')

          class_name.split('::').last.downcase
        end

        # Checks if a provider class is the Lighthouse provider
        def lighthouse_provider?(provider_class)
          provider_class.name.downcase.include?('lighthouse')
        end

        # Returns the mobile-specific Lighthouse Proxy
        # This proxy includes mobile transforms (override_rv1, suppress_evidence_requests)
        # Note: The controller should also route to the appropriate adapter, as adapters
        # may contain provider-specific logic (e.g., status code mappings)
        def lighthouse_proxy
          @lighthouse_proxy ||= Mobile::V0::LighthouseClaims::Proxy.new(@current_user)
        end
      end
    end
  end
end
