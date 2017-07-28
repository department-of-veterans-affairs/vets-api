# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module Response
        class MhvXmlHtmlErrors < Faraday::Response::Middleware
          include SentryLogging
          attr_reader :status, :body, :header, :breakers_service

          def initialize(app, _options = {})
            # @breakers_service = options[:breakers_service]
            # raise ArgumentError, 'no BreakersService provided' unless @breakers_service.is_a?(Breakers::Service)
            super(app)
          end

          def on_complete(env)
            return if env.success?
            return unless env.response_headers['content-type'] =~ /\b(xml|html)/
            status = env.status.to_i
            body = env.body.delete('%') # strip percentages from html because Sentry uses it for interpolation
            header = env.response_headers.to_s.delete('%')

            options = error_options(status: status, body: body, header: header)
            raise Common::Exceptions::BackendServiceException.new(options[:code], options)
          end

          private

          def error_options(status:, body: nil, header: nil)
            {
              status: status,
              body: body,
              header: header,
              detail: status == 503 ? 'We could not process your request at this time. Please try again later.' : nil,
              code:   status == 503 ? 'VA1003' : 'VA1000',
              source: 'Contact system administrator for additional details on what this error could mean.'
            }
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware mhv_xml_html_errors: Common::Client::Middleware::Response::MhvXmlHtmlErrors
