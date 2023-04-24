# frozen_string_literal: true

require 'common/client/middleware/response/raise_error'

module Rx
  module Middleware
    module Response
      class RxRaiseError < Common::Client::Middleware::Response::RaiseError
        private

        def service_i18n_key
          key = super
          key << 'LOCKED' if status == 400 && body['source']&.include?('optimistic locking failed')
          key
        end
      end
    end
  end
end

Faraday::Response.register_middleware rx_raise_error: Rx::Middleware::Response::RxRaiseError
