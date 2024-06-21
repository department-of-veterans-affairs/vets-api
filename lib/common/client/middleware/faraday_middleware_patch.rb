# frozen_string_literal: true

# require 'faraday'

module FaradayMiddlewarePatch
  def initialize(app = nil, options = {})
    @app = app
    @options = @@default_options.merge(options)
  end

  def self.default_options=(options = {})
    @@default_options ||= {} # rubocop:disable Style/ClassVars
    @@default_options.merge!(options)
  end
end
