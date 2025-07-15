# frozen_string_literal: true

require 'common/client/middleware/response/raise_custom_error'

module Rx
  module Middleware
    module Response
      class RxRaiseError < Common::Client::Middleware::Response::RaiseCustomError
        private

        def service_i18n_key
          key = super
          if status == 400 && (body['source']&.include?('optimistic locking failed') || 
                               body['developerMessage']&.include?('optimistic locking failed'))
            key << 'LOCKED'
          end
          key
        end
      end
    end
  end
end

Faraday::Response.register_middleware rx_raise_error: Rx::Middleware::Response::RxRaiseError
