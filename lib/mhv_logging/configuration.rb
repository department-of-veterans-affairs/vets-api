# frozen_string_literal: true
require 'singleton'
module MHVLogging
  # Configuration class used to setup the environment used by client
  class Configuration
    include Singleton

    attr_reader :host, :app_token, :open_timeout, :read_timeout

    def initialize
      @host = ENV['MHV_HOST']
      @app_token = ENV['MHV_APP_TOKEN']
      @open_timeout = 15
      @read_timeout = 15
    end

    def base_path
      "#{host}/mhv-api/patient/v1/"
    end

    def breakers_service
      return @service if defined?(@service)

      path = URI.parse(base_path).path
      host = URI.parse(base_path).host
      matcher = proc do |request_env|
        request_env.url.host == host && request_env.url.path =~ /^#{path}/
      end

      @service = Breakers::Service.new(
        name: 'MHVLogging',
        request_matcher: matcher
      )
    end
  end
end
