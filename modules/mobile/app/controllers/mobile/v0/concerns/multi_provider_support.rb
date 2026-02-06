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

        # Returns both provider type and claim response for adapter routing
        # @return [Hash] hash with :provider_type and :claim_response keys
        def get_claim_with_provider_type(claim_id, provider_type = nil)
          # Determine actual provider type
          actual_provider_type = if provider_type.present?
                                   provider_type.to_s.downcase
                                 elsif configured_providers.length == 1
                                   detect_provider_type(configured_providers.first)
                                 else
                                   # Default to lighthouse for backward compatibility
                                   'lighthouse'
                                 end

          claim_response = get_claim_from_providers(claim_id, provider_type)

          {
            provider_type: actual_provider_type,
            claim_response:
          }
        end

        # Overrides base implementation to use explicit routing instead of fallback iteration.
        #
        # Retrieves a claim from the appropriate provider based on provider_type parameter.
        #
        # For Lighthouse claims, routes through Mobile::V0::LighthouseClaims::Proxy to apply
        # mobile-specific transforms (override_rv1, suppress_evidence_requests, schema validation).
        # Other providers use their provider implementation directly.
        #
        # When type parameter is missing:
        # - Single provider: Uses lighthouse / benefits-claims
        # - Multiple providers: Default to Lighthouse (maintains existing bookmarked URLs)
        def get_claim_from_providers(claim_id, provider_type = nil)
          # If provider_type is specified, route based on type
          return get_claim_for_provider_type(claim_id, provider_type) if provider_type.present?

          # No provider_type specified - check provider count
          if configured_providers.length == 1
            # Single provider - use it (whatever it is)
            provider_class = configured_providers.first
            if lighthouse_provider?(provider_class)
              lighthouse_claims_proxy.get_claim(claim_id)
            else
              provider = provider_class.new(@current_user)
              provider.get_claim(claim_id)
            end
          else
            # Multiple providers - default to Lighthouse
            lighthouse_claims_proxy.get_claim(claim_id)
          end
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
          ['lighthouse']
        end

        # Routes claim request to appropriate implementation based on provider type
        # Lighthouse uses Proxy (with mobile transforms), others use provider directly
        def get_claim_for_provider_type(claim_id, provider_type)
          case provider_type.to_s.downcase
          when 'lighthouse'
            lighthouse_claims_proxy.get_claim(claim_id)
          else
            provider_class = provider_class_for_type(provider_type)
            provider = provider_class.new(@current_user)
            provider.get_claim(claim_id)
          end
        end

        # Checks if a provider class is the Lighthouse provider
        def lighthouse_provider?(provider_class)
          provider_class.name.include?('Lighthouse')
        end

        # Detects provider type string from provider class
        def detect_provider_type(provider_class)
          if lighthouse_provider?(provider_class)
            'lighthouse'
          else
            provider_class.name.split('::').last.gsub(/Provider$/, '').underscore
          end
        end

        # Returns the mobile-specific Lighthouse Proxy
        # This proxy includes mobile transforms (override_rv1, suppress_evidence_requests)
        def lighthouse_claims_proxy
          Mobile::V0::LighthouseClaims::Proxy.new(@current_user)
        end
      end
    end
  end
end
