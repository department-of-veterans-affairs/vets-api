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
    end
  end
end
