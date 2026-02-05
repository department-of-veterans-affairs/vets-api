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
          ['lighthouse']
        end
      end
    end
  end
end
