# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module Response
        class MhvXmlHtmlErrors < Faraday::Response::Middleware
          include SentryLogging
          attr_reader :status, :breakers_service

          def initialize(app, options = {})
            @breakers_service = options[:breakers_service]
            binding.pry
            raise ArgumentError, 'no BreakersService provided' unless @breakers_service.is_a?(Breakers::Service)
            super(app)
          end

          def on_complete(env)
            return if env.success?
            return unless env.response_headers['content-type'] =~ /\b(xml|html)/
            @status = env.status.to_i
            body = env.body.delete('%') # strip percentages from html because Sentry uses it for interpolation
            header = env.response_headers.to_s.delete('%')

            # Logging the header as well, because it can include a Retry-After in the header if known
            # This might be useful for improved handling with breakers
            extra_context = { original_status: @status, original_body: body, original_header: header }
            # eventually we won't need to log_message_to_sentry for 503, but lets do it for now
            log_message_to_sentry('Could not parse XML/HTML response from MHV', :warn, extra_context)
            if @status == 503
              # NOTE: begin_forced_outage! would need manual intervention to resolve
              # NOTE: We might find that throttling like this is unnecessary, or could be improved based on Retry-After
              Breakers::Outage.create(service: breakers_service)
              raise Breakers::OutageException.new(breakers_service.latest_outage, breakers_service)
            else
              raise Common::Exceptions::BackendServiceException.new('VA900', response_values, @status, body)
            end
          end

          private

          def response_values
            {
              status: status,
              detail: 'Received an error response that could not be processed',
              code:   'VA900',
              source: 'MHV provided unparsable error response, check logs for original request body.'
            }
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware mhv_xml_html_errors: Common::Client::Middleware::Response::MhvXmlHtmlErrors
