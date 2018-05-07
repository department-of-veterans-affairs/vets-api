# frozen_string_literal: true

require 'common/client/base'
require 'evss/auth_headers'

module EVSS
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.evss'

    def initialize(user)
      @user = user
    end

    def perform(method, path, body = nil, headers = {})
      headers = headers_for_user(@user).merge(headers)
      super(method, path, body, headers)
    end

    def headers
      { 'Content-Type' => 'application/json' }
    end

    private

    def headers_for_user(user)
      EVSS::AuthHeaders.new(user).to_h
    end

    def handle_error(error)
      case error
      when Faraday::ParsingError
        log_message_to_sentry(error.message, :error, extra_context: { url: config.base_path })
        raise_backend_exception('EVSS502', self.class)
      when Common::Client::Errors::ClientError
        log_message_to_sentry(error.message, :error, extra_context: { url: config.base_path, body: error.body })
        raise Common::Exceptions::Forbidden if error.status == 403
        raise_backend_exception('EVSS400', self.class, error) if error.status == 400
        raise_backend_exception('EVSS502', self.class, error)
      else
        raise error
      end
    end

    def raise_backend_exception(key, source, error = nil)
      ex = service_exception || Common::Exceptions::BackendServiceException
      raise ex.new(
        key,
        { source: "EVSS::#{source}" },
        error&.status,
        error&.body
      )
    end
  end
end
