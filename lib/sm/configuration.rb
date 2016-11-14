# frozen_string_literal: true
require 'singleton'

module SM
  class Configuration
    include Singleton

    attr_reader :host, :app_token, :open_timeout, :read_timeout

    def initialize
      @host = ENV['MHV_SM_HOST']
      @app_token = ENV['MHV_SM_APP_TOKEN']
      @open_timeout = 15
      @read_timeout = 15
    end

    def base_path
      "#{@host}/mhv-sm-api/patient/v1/"
    end

    def breakers_service
      return @service if defined?(@service)

      path = URI.parse(base_path).path
      host = URI.parse(base_path).host
      matcher = proc do |request_env|
        request_env.url.host == host && request_env.url.path =~ /^#{path}/
      end

      exception_handler = proc do |exception|
        # :nocov:
        if exception.is_a?(Common::Client::Errors::ClientResponse)
          (500..599).cover?(exception.major)
        else
          false
        end
        # :nocov:
      end

      @service = Breakers::Service.new(
        name: 'SM',
        request_matcher: matcher,
        exception_handler: exception_handler
      )
    end
  end
end
