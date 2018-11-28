# frozen_string_literal: true

module Common::Client
  module FaradayMiddlewareCheck
    private

    def faraday_config_check(handlers)
      check_for_remove_cookies(handlers)
      check_for_breakers_and_rescue_timeout_placement(handlers)
    end

    def check_for_remove_cookies(handlers)
      if handlers.include?(Faraday::Adapter::HTTPClient) &&
         !handlers.include?(Common::Client::Middleware::Request::RemoveCookies)
        raise SecurityError, 'http client needs cookies stripped'
      end
    end

    def check_for_breakers_and_rescue_timeout_placement(handlers)
      breakers_index = handlers.index(Breakers::UptimeMiddleware)
      rescue_timeout_index = handlers.index(Common::Client::Middleware::Request::RescueTimeout)

      if rescue_timeout_index&.positive? || (breakers_index&.> 1)
        raise BreakersImplementationError,
              ':rescue_timeout should be the first middleware implemented, and Breakers should be the second.'
      end

      if rescue_timeout_index.nil? && breakers_index&.positive?
        raise BreakersImplementationError, 'Breakers should be the first middleware implemented.'
      end

      if self.class.try(:configuration).try(:service_name) && !breakers_index
        warn("Breakers is not implemented for service: #{self.class.configuration.service_name}")
      end
    end
  end
end
