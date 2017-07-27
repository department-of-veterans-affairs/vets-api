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
              # In the future we might want to try to throttle with Retry-After
              # Breakers::Outage.create(service: breakers_service)
              # raise Breakers::OutageException.new(breakers_service.latest_outage, breakers_service)
              # But for now, lets just raise something that triggers breakers
              raise_error('VA1003')
            else
              raise_error('VA1000')
            end
          end

          private

          def raise_error(type)
            raise Common::Exceptions::BackendServiceException.new(type, response_values(type), status, body, header)
          end

          def response_values(type)
            {
              status: status,
              code:   type,
              source: 'Contact system administrator for additional details on what this error could mean.'
            }
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware mhv_xml_html_errors: Common::Client::Middleware::Response::MhvXmlHtmlErrors
