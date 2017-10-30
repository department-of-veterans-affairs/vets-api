# frozen_string_literal: true
require 'common/client/base'
require 'evss/auth_headers'

module EVSS
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.evss'

    protected

    def headers_for_user(user)
      EVSS::AuthHeaders.new(user).to_h
    end

    def with_monitoring
      caller = caller_locations(1, 1)[0].label
      yield
    rescue StandardError => error
      StatsD.increment("#{STATSD_KEY_PREFIX}.#{caller}.fail", tags: ["error:#{error.class}"])
      handle_error(error)
    ensure
      StatsD.increment("#{STATSD_KEY_PREFIX}.#{caller}.total")
    end

    def raise_backend_exception(key, source, error = nil)
      raise Common::Exceptions::BackendServiceException.new(
        key,
        { source: "EVSS::#{source}" },
        error&.status,
        error&.body
      )
    end

    def handle_error(error)
      case error
      when Faraday::ParsingError
        log_message_to_sentry(error.message, :error, extra_context: { url: config.base_path })
        raise_backend_exception('EVSS502', self.class)
      when Common::Client::Errors::ClientError
        raise Common::Exceptions::Forbidden if error.status == 403
        log_message_to_sentry(error.message, :error, extra_context: { url: config.base_path, body: error.body })
        raise_backend_exception('EVSS400', self.class, error) if error.status == 400
        raise_backend_exception('EVSS502', self.class, error)
      else
        raise error
      end
    end
  end
end
