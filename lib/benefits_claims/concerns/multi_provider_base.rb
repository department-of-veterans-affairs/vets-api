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

      def configured_providers
        BenefitsClaims::Providers::ProviderRegistry.enabled_provider_classes(@current_user)
      end

      def get_claims_from_providers
        claims_data = []
        errors = []

        configured_providers.each do |provider_class|
          provider = provider_class.new(@current_user)
          response = provider.get_claims
          claims_data.concat(extract_claims_data(provider_class, response))
        rescue Common::Exceptions::Unauthorized, Common::Exceptions::Forbidden => e
          raise e
        rescue => e
          handle_provider_error(provider_class, e, errors)
        end

        format_get_claims_response(claims_data, errors)
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

      def handle_provider_error(provider_class, error, errors)
        provider_name = provider_class.name
        errors << format_error_entry(provider_name, 'Provider temporarily unavailable')

        ::Rails.logger.warn(
          "Provider #{provider_name} failed",
          { provider: provider_name, error_class: error.class.name }
        )
        StatsD.increment(statsd_metric_name('provider_error'), tags: statsd_tags_for_provider(provider_name))
      end

      def get_claim_from_providers(claim_id)
        configured_providers.each do |provider_class|
          provider = provider_class.new(@current_user)
          response = provider.get_claim(claim_id)
          return response if validate_claim_response(response)
        rescue Common::Exceptions::RecordNotFound
          log_claim_not_found(provider_class)
        rescue Common::Exceptions::Unauthorized, Common::Exceptions::Forbidden => e
          raise e
        rescue => e
          handle_get_claim_error(provider_class, e)
        end

        raise Common::Exceptions::RecordNotFound, claim_id
      end

      def validate_claim_response(response)
        response && response['data']
      end

      def log_claim_not_found(provider_class)
        ::Rails.logger.info(
          "Provider #{provider_class.name} doesn't have claim",
          { error_class: 'Common::Exceptions::RecordNotFound' }
        )
      end

      def handle_get_claim_error(provider_class, error)
        provider_name = provider_class.name

        ::Rails.logger.error(
          "Provider #{provider_name} error fetching claim",
          { error_class: error.class.name, backtrace: error.backtrace&.first(3) }
        )
        StatsD.increment(statsd_metric_name('get_claim.provider_error'),
                         tags: statsd_tags_for_provider(provider_name))
      end

      # Template methods - must be implemented by including modules
      def format_error_entry(_provider_name, _message)
        raise NotImplementedError, 'Subclasses must implement format_error_entry'
      end

      def format_get_claims_response(_claims_data, _errors)
        raise NotImplementedError, 'Subclasses must implement format_get_claims_response'
      end

      def statsd_metric_name(_action)
        raise NotImplementedError, 'Subclasses must implement statsd_metric_name'
      end

      def statsd_tags_for_provider(_provider_name)
        raise NotImplementedError, 'Subclasses must implement statsd_tags_for_provider'
      end
    end
  end
end
