# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module Response
        class RaiseError < Faraday::Response::Middleware
          attr_reader :error_prefix, :body, :status

          def initialize(app, options = {})
            # set the error prefix to something like 'RX' or 'SM'
            @error_prefix = options[:error_prefix] || 'VA'
            super(app)
          end

          def on_complete(env)
            return if env.success?
            @body = env[:body]
            @status = env.status.to_i
            raise_error!
          end

          private

          def raise_error!
            if status&.between?(400, 599)
              raise Common::Exceptions::BackendServiceException.new(service_i18n_key, error_options)
            else
              raise Common::Exceptions::BackendServiceException('VA1000', error_options)
            end
          end

          def service_i18n_key
            "#{error_prefix.upcase}#{body['code']}"
          end

          def error_options
            {
              status: status,
              detail: body['detail'],
              code:   service_i18n_key,
              source: body['source'],
              body: body
            }
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware raise_error: Common::Client::Middleware::Response::RaiseError
