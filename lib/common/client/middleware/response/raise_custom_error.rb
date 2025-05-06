# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class BackendUnhandledException < StandardError; end

        class RaiseCustomError < Faraday::Middleware
          attr_reader :error_prefix, :body, :status, :allow_not_modified

          def initialize(app, options = {})
            # set the error prefix to something like 'RX' or 'SM'
            @error_prefix = options[:error_prefix] || 'VA'
            @allow_not_modified = options[:allow_not_modified] || false
            super(app)
          end

          def on_complete(env)
            return if env.success?

            @body = env[:body]
            @status = env.status.to_i
            raise_error! unless not_modified?
          end

          private

          def raise_error!
            if status&.between?(400, 599)
              raise Common::Exceptions::BackendServiceException.new(service_i18n_key, response_values, status, body)
            else
              raise BackendUnhandledException, "Unhandled Exception - status: #{status}, body: #{body}"
            end
          end

          def service_i18n_key
            if body['code']
              "#{error_prefix.upcase}#{body['code']}"
            else
              "#{error_prefix.upcase}_#{status}"
            end
          end

          def response_values
            {
              status:,
              detail: body['detail'],
              code: service_i18n_key,
              source: body['source']
            }
          end

          def not_modified?
            allow_not_modified && status == 304
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware raise_custom_error: Common::Client::Middleware::Response::RaiseCustomError
