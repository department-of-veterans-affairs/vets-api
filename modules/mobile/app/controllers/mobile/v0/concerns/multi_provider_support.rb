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
      end
    end
  end
end
