# frozen_string_literal: true

module FaradayMiddlewarePatch
  @@default_options = {} # rubocop:disable Style/ClassVars

  def initialize(app = nil, options = {})
    @app = app
    @options = @@default_options.merge(options)
  end

  def self.prepended(base)
    class << base
      def default_options=(options = {})
        @@default_options.merge!(options)
      end
    end
  end
end

Faraday::Response::RaiseError.prepend(FaradayMiddlewarePatch)
