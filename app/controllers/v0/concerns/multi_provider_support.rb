# frozen_string_literal: true

module V0
  module Concerns
    module MultiProviderSupport
      extend ActiveSupport::Concern

      private

      def configured_providers
        BenefitsClaims::Providers::ProviderRegistry.enabled_provider_classes(@current_user)
      end

      def get_claims_from_providers
        return configured_providers.first.new(@current_user).get_claims if configured_providers.count == 1

        claims_data = []
        provider_errors = []
        configured_providers.each do |provider_class|
          provider = provider_class.new(@current_user)
          claims_data.concat(provider.get_claims['data'])
        rescue => e
          handle_provider_error(provider_class, e, provider_errors)
        end
        { 'data' => claims_data, 'meta' => { 'provider_errors' => provider_errors.presence }.compact }
      end

      def handle_provider_error(provider_class, error, provider_errors)

        provider_errors << { provider: provider_class.name, error: 'Provider temporarily unavailable' }

        ::Rails.logger.error(
          "Provider #{provider_class.name} failed",
          { error_class: error.class.name, backtrace: error.backtrace&.first(3) }
        )
        StatsD.increment("#{self.class::STATSD_METRIC_PREFIX}.provider_error",
                         tags: self.class::STATSD_TAGS + ["provider:#{provider_class.name}"])
      end

      def get_claim_from_providers(claim_id)
        return configured_providers.first.new(@current_user).get_claim(claim_id) if configured_providers.count == 1

        configured_providers.each do |provider_class|
          return provider_class.new(@current_user).get_claim(claim_id)
        rescue => e
          ::Rails.logger.info(
            "Provider #{provider_class.name} doesn't have claim",
            { error_class: e.class.name }
          )
        end
        raise Common::Exceptions::RecordNotFound, claim_id
      end
    end
  end
end
