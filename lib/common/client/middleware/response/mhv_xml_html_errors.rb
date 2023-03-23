# frozen_string_literal: true

require 'sentry_logging'

module Common
  module Client
    module Middleware
      module Response
        ##
        # Faraday response middleware that checks the MHV service XML/HTML response for errors and raises
        # the appropriate exception for our application.
        #
        class MHVXmlHtmlErrors < Faraday::Response::Middleware
          include SentryLogging
          attr_reader :status

          ##
          # @raise [Common::Exceptions::BackendServiceException] if there are parsing errors
          # @return [Faraday::Env]
          #
          def on_complete(env)
            return if env.success?
            return unless env.response_headers['content-type']&.match?(/\b(xml|html)/)

            @status = env.status.to_i
            @body = env.body.delete('%') # strip percentages from html because Sentry uses it for interpolation

            extra_context = { original_status: @status, original_body: @body }
            log_message_to_sentry('Could not parse XML/HTML response from MHV', :warn, extra_context)
            raise Common::Exceptions::BackendServiceException.new('VA900', response_values, @status, @body)
          end

          private

          def response_values
            {
              status:,
              detail: 'Received an error response that could not be processed',
              code: 'VA900',
              source: 'MHV provided unparsable error response, check logs for original request body.'
            }
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware mhv_xml_html_errors: Common::Client::Middleware::Response::MHVXmlHtmlErrors
