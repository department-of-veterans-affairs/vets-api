# frozen_string_literal: true

module Commons
  class Connection
    attr_reader :base_url,
                :service_name,
                :statd_key_prefix,
                :faraday_connection,
                :allowed_request_types

    def initialize(connection_options, &)
      @base_url = connection_options[:base_url]
      @timeouts = connection_options[:timeouts] || {}
      @service_name = connection_options[:service_name]
      @statd_key_prefix = connection_options[:statd_key_prefix]
      @allowed_request_types = connection_options[:allowed_request_types]
      @faraday_connection = create_and_validate_faraday_connection(&)
    end

    def self.configure(connection_options = {}, &)
      new(connection_options, &)
    end

    def get(path, params, headers, options = nil)
      request(:get, path, params, headers, options)
    end

    def post(path, params, headers, options = nil)
      request(:post, path, params, headers, options)
    end

    def put(path, params, headers, options = nil)
      request(:put, path, params, headers, options)
    end

    def delete(path, params, headers, options = nil)
      request(:delete, path, params, headers, options)
    end

    private

    def create_and_validate_faraday_connection
      faraday = Faraday.new(url: @base_url) do |conn|
        conn.options.read_timeout = @timeouts[:read] || 15
        conn.options.open_timeout = @timeouts[:open] || 15
        yield conn if block_given?
      end

      handlers = faraday.builder.handlers
      adapter = faraday.builder.adapter

      validate_cookies_stripped(adapter, handlers)
      validate_breakers_middleware(handlers)

      faraday
    end

    def request(method, path, params = {}, headers = {}, options = {})
      Datadog::Tracing.active_span&.set_tag('common_client_service', service_name)

      headers = sanitized_headers(headers)
      validate_authenticated(headers)

      faraday_connection.send(method.to_sym, path, params) do |request|
        request.headers.update(headers)
        options.each { |option, value| request.options.send("#{option}=", value) }
      end.env
    rescue Common::Exceptions::BackendServiceException => e
      raise_service_exception(e)
    rescue Timeout::Error, Faraday::TimeoutError => e
      raise_timeout_error(e, path)
    rescue Faraday::ClientError, Faraday::ServerError, Faraday::Error => e
      raise_response_error(e)
    end

    def sanitized_headers(headers)
      headers.transform_keys!(&:to_s)
      headers.transform_values! { |value| value || '' }
      headers
    end

    def validate_authenticated(headers)
      unless headers.keys.include?('Token') && headers['Token']
        raise Common::Client::Errors::NotAuthenticated, 'Not Authenticated'
      end
    end

    def raise_service_exception(e)
      # convert BackendServiceException into a more meaningful exception title for Sentry
      raise service_exception.new(e.key, e.response_values, e.original_status, e.original_body)
    end

    def raise_timeout_error(e, path)
      Sentry.set_extras(service_name:, url: path)
      raise Common::Exceptions::GatewayTimeout, e.class.name
    end

    def raise_response_error(e)
      case e
      when Faraday::ParsingError
        Common::Client::Errors::ParsingError
      else
        Common::Client::Errors::ClientError
      end

      response_hash = e.response&.to_hash
      status = response_hash&.dig(:status)
      body = esponse_hash&.dig(:body)
      error_class.new(e.message, status, body)
    end

    def service_exception
      if current_module.const_defined?('ServiceException')
        current_module.const_get('ServiceException')
      else
        current_module.const_set('ServiceException', Class.new(Common::Exceptions::BackendServiceException))
      end
    end

    def validate_cookies_stripped(adapter, handlers)
      is_http_client = adapter == Faraday::Adapter::HTTPClient
      if is_http_client && handlers.exclude?(Common::Client::Middleware::Request::RemoveCookies)
        raise SecurityError, 'http client needs cookies stripped'
      end
    end

    def validate_breakers_middleware(handlers)
      unless handlers.include?(Breakers::UptimeMiddleware)
        warn_missing_breakers
        return
      end

      if handlers.first == Breakers::UptimeMiddleware
        raise BreakersImplementationError, 'Breakers should be the first middleware implemented.'
      end
    end

    def missing_breakers_warning
      warn("Breakers is not implemented for service: #{service_name}")
    end

    # deconstantize fetches "AA::BB::" from AA::BB::ClassName, and constantize returns that as a constant.
    def current_module
      self.class.name.deconstantize.constantize
    end
  end
end
