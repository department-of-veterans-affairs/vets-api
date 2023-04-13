# frozen_string_literal: true

require 'statsd-instrument' unless Object.const_defined?(:StatsD)

# This monkeypatch is used to fix StatsD metrics that were breaking following the vets-api EKS transition.
# Prior to the transition, there was a service that substituted dots in StatsD keys with underscores.
# After the EKS transition, StatsD keys were being reported with dots, breaking existing metrics expecting underscores.
# For example, this monkeypatch will take the key: 'api.service.total', and transform it to: 'api_service_total'
module StatsD
  module Instrument
    module Underscore
      def increment(key, value = 1, sample_rate: nil, tags: nil, no_prefix: false)
        super(substitute_dots_for_underscores(key), value, sample_rate:, tags:, no_prefix:)
      end

      def gauge(key, value, sample_rate: nil, tags: nil, no_prefix: false)
        super(substitute_dots_for_underscores(key), value, sample_rate:, tags:, no_prefix:)
      end

      def histogram(key, value, sample_rate: nil, tags: nil, no_prefix: false)
        super(substitute_dots_for_underscores(key), value, sample_rate:, tags:, no_prefix:)
      end

      def set(key, value, sample_rate: nil, tags: nil, no_prefix: false)
        super(substitute_dots_for_underscores(key), value, sample_rate:, tags:, no_prefix:)
      end

      def measure(key, value = nil, sample_rate: nil, tags: nil, no_prefix: false, &block)
        super(substitute_dots_for_underscores(key), value, sample_rate:, tags:, no_prefix:, &block)
      end

      def distribution(key, value = nil, sample_rate: nil, tags: nil, no_prefix: false, &block)
        super(substitute_dots_for_underscores(key), value, sample_rate:, tags:, no_prefix:, &block)
      end

      private

      def substitute_dots_for_underscores(key)
        key.gsub('.', '_')
      end
    end
  end
end

StatsD::Instrument::Client.prepend(StatsD::Instrument::Underscore) unless Rails.env.test?
