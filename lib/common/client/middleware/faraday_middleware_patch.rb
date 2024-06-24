# frozen_string_literal: true

module FaradayMiddlewarePatch
  def initialize(app = nil, options = {})
    @app = app
    @options = self.class.default_options.merge(options)
  end

  def self.prepended(base)
    class << base
      def default_options=(options = {})
        @@default_options ||= {} # rubocop:disable Style/ClassVars
        @@default_options.merge!(options)
      end
    end
  end
end

Faraday::Response::RaiseError.prepend(FaradayMiddlewarePatch)
