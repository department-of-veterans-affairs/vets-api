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
               Common::Exceptions::Forbidden,
               Common::Exceptions::GatewayTimeout,
               Common::Exceptions::ServiceUnavailable,
               Common::Exceptions::ResourceNotFound => e
          raise e
        rescue => e
          handle_provider_error(provider_class, e, provider_errors)
        end
        { 'data' => claims_data, 'meta' => { 'provider_errors' => provider_errors.presence }.compact }
      end

      def extract_claims_data(provider_class, response)
        if response.nil?
          ::Rails.logger.warn("Provider #{provider_class.name} returned nil from get_claims")
          return []
        end

        unless response.is_a?(Hash) && response.key?('data')
          ::Rails.logger.error(
            "Provider #{provider_class.name} returned unexpected structure from get_claims",
            {
              provider: provider_class.name,
              response_class: response.class.name,
              has_data_key: response.is_a?(Hash) && response.key?('data')
            }
          )
          return []
        end

        response['data'] || []
      end

      def handle_provider_error(provider_class, error, provider_errors)
        provider_errors << { 'provider' => provider_class.name, 'error' => 'Provider temporarily unavailable' }

        ::Rails.logger.error(
          "Provider #{provider_class.name} failed",
          { error_class: error.class.name, backtrace: error.backtrace&.first(3) }
        )
        StatsD.increment("#{self.class::STATSD_METRIC_PREFIX}.provider_error",
                         tags: self.class::STATSD_TAGS + ["provider:#{provider_class.name}"])
      end

      def get_claim_from_providers(claim_id)
        configured_providers.each do |provider_class|
          provider = provider_class.new(@current_user)
          return provider.get_claim(claim_id)
        rescue Common::Exceptions::RecordNotFound
          log_claim_not_found(provider_class)
        rescue Common::Exceptions::Unauthorized,
               Common::Exceptions::Forbidden,
               Common::Exceptions::GatewayTimeout,
               Common::Exceptions::ServiceUnavailable,
               Common::Exceptions::ResourceNotFound => e
          raise e
        rescue => e
          handle_get_claim_error(provider_class, e)
        end
        raise Common::Exceptions::RecordNotFound, claim_id
      end

      def log_claim_not_found(provider_class)
        # Expected case: this provider doesn't have the claim, try next provider
        ::Rails.logger.info(
          "Provider #{provider_class.name} doesn't have claim",
          { error_class: 'Common::Exceptions::RecordNotFound' }
        )
      end

      def handle_get_claim_error(provider_class, error)
        # Unexpected error: log and try next provider
        ::Rails.logger.error(
          "Provider #{provider_class.name} error fetching claim",
          { error_class: error.class.name, backtrace: error.backtrace&.first(3) }
        )
        StatsD.increment("#{self.class::STATSD_METRIC_PREFIX}.get_claim.provider_error",
                         tags: self.class::STATSD_TAGS + ["provider:#{provider_class.name}"])
      end
    end
  end
end
