# frozen_string_literal: true

require_relative './middleware/response/errors'
require_relative './middleware/vaos_logging'

module VAOS
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.va_mobile.timeout || 15

    def base_path
      Settings.va_mobile.url
    end

    def service_name
      'VAOS'
    end

    def rsa_key
      @key ||= OpenSSL::PKey::RSA.new(File.read(Settings.va_mobile.key_path))
    end

    ##
    # Overridden from Configuration::Base
    # We want a custom error threshold for breakers outages to get triggered because the there are a large number
    # of endpoints and they all resolve to the same url so 50% might cause 1 or 2 endpoints to break the whole app.
    # In the future we might look at playing around with the matcher based on client class names instead instead of URI.
    #
    # @return Hash default request options.
    #
    # rubocop:disable Metrics/MethodLength
    def breakers_service
      return @service if defined?(@service)

      base_uri = URI.parse(base_path)
      matcher = proc do |request_env|
        request_env.url.host == base_uri.host && request_env.url.port == base_uri.port &&
          request_env.url.path =~ /^#{base_uri.path}/
      end

      exception_handler = proc do |exception|
        if exception.is_a?(Common::Exceptions::BackendServiceException)
          (500..599).cover?(exception.response_values[:status])
        elsif exception.is_a?(Common::Client::Errors::HTTPError)
          (500..599).cover?(exception.status)
        else
          false
        end
      end

      @service = Breakers::Service.new(
        name: service_name,
        request_matcher: matcher,
        error_threshold: 90,
        exception_handler: exception_handler
      )
    end
    # rubocop:enable Metrics/MethodLength

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.request :camelcase
        conn.request :json

        if ENV['VAOS_DEBUG'] && !Rails.env.production?
          conn.request(:curl, ::Logger.new(STDOUT), :warn)
          conn.response(:logger, ::Logger.new(STDOUT), bodies: true)
        end

        conn.response :betamocks if mock_enabled?
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.response :vaos_errors
        conn.use :vaos_logging
        conn.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      [true, 'true'].include?(Settings.va_mobile.mock)
    end
  end
end
