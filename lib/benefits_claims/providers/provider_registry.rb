# frozen_string_literal: true

require 'concurrent/map'

module BenefitsClaims
  module Providers
    class ProviderRegistry
      @registry = Concurrent::Map.new

      class << self
        attr_reader :registry
        private :registry

        def register(provider_name, provider_class, options = {})
          registry[provider_name] = {
            class: provider_class,
            feature_flag: options[:feature_flag],
            enabled_by_default: options.fetch(:enabled_by_default, false)
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
          registry.clear
        end
      end
    end
  end
end
