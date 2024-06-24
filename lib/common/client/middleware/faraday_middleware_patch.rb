# frozen_string_literal: true

# require 'faraday'

module FaradayMiddlewarePatch
  def initialize(app = nil, options = {})
    @app = app
    @options = self.class.default_options.merge(options)
  end

  def self.prepended(base)
    class << base
      def default_options=(options = {})
        @default_options ||= {}
        @default_options.merge!(options)
      end

      def default_options
        @default_options ||= {}
      end
    end
  end
end

Faraday::Middleware.prepend(FaradayMiddlewarePatch)
