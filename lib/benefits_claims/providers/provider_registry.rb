# frozen_string_literal: true

require 'concurrent/map'

module BenefitsClaims
  module Providers
    # Centralized registry for managing multiple benefits claims data providers.
    #
    # The ProviderRegistry maintains a thread-safe collection of provider implementations
    # that can be dynamically enabled/disabled via feature flags or default configuration.
    # This allows the application to aggregate claims data from multiple sources
    # (e.g., Lighthouse, CHAMPVA) without requiring code changes.
    #
    # ## Thread Safety
    # Uses Concurrent::Map for thread-safe concurrent access. Safe to call from
    # multiple threads without external synchronization.
    #
    # ## Provider Registration
    # Providers are registered with a unique name, class, and optional configuration:
    # - feature_flag: Name of Flipper feature flag for runtime control
    # - enabled_by_default: Boolean indicating if provider is enabled when no feature flag exists
    #
    # ## Feature Flag Behavior
    # Provider enablement follows this priority:
    # 1. If feature_flag is specified and Flipper is available: Use Flipper.enabled?(flag, user)
    # 2. Otherwise: Use enabled_by_default value
    #
    # ## Example Usage
    #   # Register providers (typically in an initializer)
    #   ProviderRegistry.register(
    #     :lighthouse,
    #     BenefitsClaims::Providers::Lighthouse::LighthouseBenefitsClaimsProvider,
    #     feature_flag: 'benefits_claims_lighthouse_provider',
    #     enabled_by_default: true
    #   )
    #
    #   ProviderRegistry.register(
    #     :champva,
    #     BenefitsClaims::Providers::Champva::ChampvaBenefitsClaimsProvider,
    #     feature_flag: 'benefits_claims_champva_provider',
    #     enabled_by_default: false
    #   )
    #
    #   # Get enabled providers for a user
    #   enabled_classes = ProviderRegistry.enabled_provider_classes(current_user)
    #   # => [LighthouseBenefitsClaimsProvider, ChampvaBenefitsClaimsProvider]
    #
    #   # Check if specific provider is enabled
    #   ProviderRegistry.enabled?(:lighthouse, current_user) # => true
    #
    class ProviderRegistry
      @registry = Concurrent::Map.new

      class << self
        attr_reader :registry
        private :registry

        def register(provider_name, provider_class, options = {})
          registry[provider_name] = {
            class: provider_class,
            feature_flag: options[:feature_flag],
            enabled_by_default: ActiveModel::Type::Boolean.new.cast(options.fetch(:enabled_by_default, false))
          }
        end

        def enabled_provider_classes(user = nil)
          registry.each.with_object([]) do |(name, config), result|
            result << config[:class] if enabled?(name, user)
          end
        end

        def enabled?(provider_name, user = nil)
          config = registry[provider_name]
          return false unless config

          return Flipper.enabled?(config[:feature_flag], user) if config[:feature_flag] && defined?(Flipper)

          config[:enabled_by_default]
        end

        # Clear all registered providers (useful for testing)
        def clear!
          raise 'ProviderRegistry.clear! cannot be called in production' if Rails.env.production?

          registry.clear
        end
      end
    end
  end
end
