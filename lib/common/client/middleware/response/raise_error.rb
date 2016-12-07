# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module Response
        class BackendUnhandledException < StandardError; end

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
            if response_values[:status]&.between?(400, 499)
              raise Common::Exceptions::BackendServiceException.new(i18n_key, response_values)
            else
              raise BackendUnhandledException, "Unhandled Exception - status: #{@status}, body: #{@body}"
            end
          end

          def i18n_key
            if I18n.exists?("common.exceptions.#{error_prefix.upcase}#{body['code']}")
              "#{error_prefix.upcase}#{body['code']}"
            else
              'VA900'
            end
          end

          def response_values
            {
              status: status,
              detail: body['detail'],
              code:   i18n_key,
              source: body['source']
            }
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware raise_error: Common::Client::Middleware::Response::RaiseError
