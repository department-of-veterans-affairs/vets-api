module Commons
  class BaseClient
    include SentryLogging
    include Common::Client::Concerns::Monitoring

    def raise_backend_exception(key, source, error = nil)
      raise Common::Exceptions::BackendServiceException.new(
        key,
        { source: source.to_s },
        error&.status,
        error&.body
      )
    end

    def service_name
      raise NotImplementedError, 'Class must implement service_name method'
    end

    def connection
      raise NotImplementedError, 'Class must implement connection method'
    end

    def self.breakers_service
      self.new.breakers_service
    end

    ##
    # Default request options, sets the read and open timeouts.
    #
    # @return Hash default request options.
    #
    def breakers_service
      return @service if defined?(@service)

      @service = Breakers::Service.new(
        name: self.new.service_name,
        request_matcher: breakers_matcher,
        error_threshold:breakers_error_threshold,
        exception_handler: breakers_exception_handler
      )
    end

    def breakers_matcher
      base_uri = URI.parse(base_path)
      proc do |request_env|
        request_env.url.host == base_uri.host && request_env.url.port == base_uri.port &&
          request_env.url.path =~ /^#{base_uri.path}/
      end
    end

    def breakers_matcher
      base_uri = URI.parse(base_path)
      proc do |request_env|
        request_env.url.host == base_uri.host && request_env.url.port == base_uri.port &&
          request_env.url.path =~ /^#{base_uri.path}/
      end
    end

    def breakers_exception_handler
      proc do |exception|
        case exception
        when Common::Exceptions::BackendServiceException
          (500..599).cover?(exception.response_values[:status])
        when Common::Client::Errors::HTTPError
          (500..599).cover?(exception.status)
        when Faraday::ServerError
          (500..599).cover?(exception.response&.[](:status))
        else
          false
        end
      end
    end

    # The percentage of errors over which an outage will be reported as part of breakers gem
    #
    # @return [Integer] corresponding to percentage
    def breakers_error_threshold
      50
    end

  end
end
