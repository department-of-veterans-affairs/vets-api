# frozen_string_literal: true

module Preneeds
  module Middleware
    module Response
      class EoasXmlErrors < Faraday::Response::Middleware
        include SentryLogging
        attr_reader :status, :fault, :code, :detail

        def on_complete(env)
          return unless env.response_headers['content-type'] =~ /\b(xml)/

          @fault = fault_string(env)
          @code = return_code(env)

          return unless backend_error?(env) || status_200_error?(env)

          @status = status_200_error?(env) ? return_code(env) : env.status
          @detail = fault || return_description(env)

          # strip percentages from xml because Sentry uses it for interpolation
          extra_context = { original_status: status, original_body: env.body&.delete('%') }
          log_message_to_sentry('Generalized XML error response from EOAS', :warn, extra_context)
          raise Common::Exceptions::BackendServiceException.new('VA900', response_values, @status, env.body)
        end

        private

        def backend_error?(env)
          env.status != 200 && fault.present?
        end

        def status_200_error?(env)
          env.status == 200 && code&.nonzero?
        end

        def fault_string(env)
          env.body&.scan(%r{<faultstring[^<>]*>(.*)</faultstring[^<>]*>}i)&.first&.first
        end

        def return_code(env)
          env.body&.scan(%r{<returnCode[^<>]*>(.*)</returnCode[^<>]*>}i)&.first&.first&.to_i
        end

        def return_description(env)
          env.body&.scan(%r{<returnDescription[^<>]*>(.*)</returnDescription[^<>]*>}i)&.first&.first
        end

        def response_values
          {
            status: status,
            detail: detail,
            code:   'VA900',
            source: 'EOAS provided a general error response, check logs for original request body.'
          }
        end
      end
    end
  end
end

Faraday::Response.register_middleware eoas_xml_errors: Preneeds::Middleware::Response::EoasXmlErrors
