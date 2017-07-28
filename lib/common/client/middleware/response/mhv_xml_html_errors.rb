# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module Response
        class MhvXmlHtmlErrors < Faraday::Response::Middleware
          include SentryLogging
          attr_reader :status, :body, :header, :breakers_service

          def initialize(app, options = {})
            # @breakers_service = options[:breakers_service]
            # raise ArgumentError, 'no BreakersService provided' unless @breakers_service.is_a?(Breakers::Service)
            super(app)
          end

          def on_complete(env)
            return if env.success?
            return unless env.response_headers['content-type'] =~ /\b(xml|html)/
            @status = env.status.to_i
            @body = env.body.delete('%') # strip percentages from html because Sentry uses it for interpolation
            @header = env.response_headers.to_s.delete('%')

            if @status == 503
              # We could customize the detail for this based on the parsed XML and Retry-After in header
              raise_error('VA1003', detail: 'We could not process your request at this time. Please try again later.')
            else
              raise_error('VA1000')
            end
          end

          private

          def raise_error(type, detail: nil)
            error_options = {
              status: status,
              body: body,
              header: header,
              detail: detail,
              code:   type,
              source: 'Contact system administrator for additional details on what this error could mean.',
            }
            raise Common::Exceptions::BackendServiceException.new(type, error_options)
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware mhv_xml_html_errors: Common::Client::Middleware::Response::MhvXmlHtmlErrors
