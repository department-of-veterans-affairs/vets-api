# frozen_string_literal: true

module Eps
  module Middleware
    module Response
      ##
      # Middleware to extract X-Wellhive-Trace-Id from EPS response headers
      # and handle errors. Extends VAOS::Middleware::Response::Errors to
      # ensure trace ID is captured before raising exceptions.
      #
      class Errors < VAOS::Middleware::Response::Errors
        TRACE_ID_HEADER = 'x-wellhive-trace-id'

        def on_complete(env)
          extract_and_store_trace_id(env)
          super
        end

        private

        def extract_and_store_trace_id(env)
          return unless env.respond_to?(:response_headers) && env.response_headers

          trace_id = extract_trace_id_from_headers(env.response_headers)
          RequestStore.store['eps_trace_id'] = trace_id if trace_id
        end

        def extract_trace_id_from_headers(headers)
          return nil unless headers

          # Check for the header (headers are stored as strings in Faraday)
          value = headers[TRACE_ID_HEADER]
          return nil unless value

          # If it's an array, take the first element; otherwise use the value directly
          trace_id = value.is_a?(Array) ? value.first : value
          trace_id&.to_s.presence
        end
      end
    end
  end
end

Faraday::Response.register_middleware eps_errors: Eps::Middleware::Response::Errors
