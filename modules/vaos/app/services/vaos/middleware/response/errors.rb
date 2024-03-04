# frozen_string_literal: true

module VAOS
  module Middleware
    module Response
      class Errors < Faraday::Middleware
        def on_complete(env)
          return if env.success?

          Sentry.set_extras(vamf_status: env.status, vamf_body: env.response_body,
                            vamf_url: VAOS::Anonymizers.anonymize_uri_icn(env.url))
          raise VAOS::Exceptions::BackendServiceException, env
        end
      end
    end
  end
end

Faraday::Response.register_middleware vaos_errors: VAOS::Middleware::Response::Errors
