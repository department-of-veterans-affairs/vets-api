# frozen_string_literal: true

module Common::Client
  module FaradayMiddlewareCheck
    private

    def faraday_config_check(handlers)
      check_for_remove_cookies(handlers)
      check_for_breakers_and_log_timeout_as_warning_placement(handlers)
    end

    def check_for_remove_cookies(handlers)
      if handlers.include?(Faraday::Adapter::HTTPClient) &&
         !handlers.include?(Common::Client::Middleware::Request::RemoveCookies)
        raise SecurityError, 'http client needs cookies stripped'
      end
    end

    def check_for_breakers_and_log_timeout_as_warning_placement(handlers)
      breakers_index = handlers.index(Breakers::UptimeMiddleware)
      log_as_warning_index = handlers.index(Common::Client::Middleware::Request::LogTimeoutAsWarning)

      if log_as_warning_index&.positive? || (breakers_index&.> 1)
        raise BreakersImplementationError,
              ':log_timeout_as_warning should be the first middleware implemented, and Breakers should be the second.'
      end

      if log_as_warning_index.nil? && breakers_index&.positive?
        raise BreakersImplementationError, 'Breakers should be the first middleware implemented.'
      end

      if self.class.try(:configuration).try(:service_name) && !breakers_index
        warn("Breakers is not implemented for service: #{self.class.configuration.service_name}")
      end
    end
  end
end
