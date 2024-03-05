# frozen_string_literal: true

require 'common/exceptions'

module CovidVaccine
  module Middleware
    module Response
      class Errors < Faraday::Middleware
        def on_complete(env)
          return if env.success?

          add_sentry_extra_context(env)

          case env.status
          when 400
            parse_error(env, 400)
          when 500..510
            # All of these errors should be characterized as BAD GATEWAY 502
            parse_error(env, 502)
          else
            raise Common::Exceptions::BackendServiceException, 'VA900'
          end
        end

        # Adds a few additional helpful debugging contexts
        def add_sentry_extra_context(env)
          Sentry.set_extras(
            original_status: env.status,
            original_body: env.body,
            original_method: env.method,
            original_url: env.url
          )
        end

        # attempts to parse the error payload body and raise the generic BackendServiceException
        def parse_error(env, status_to_render)
          raise Common::Exceptions::BackendServiceException.new(
            "VETEXT_#{status_to_render}",
            {
              detail: parse_detail(env.body),
              code: "VETEXT_#{env.status}",
              source: "#{env.method.upcase}: #{env.url.path}"
            },
            env.status,
            env.body
          )
        end

        def parse_detail(body)
          body.split(/\s\(/).first.gsub('&quot;', '')
        rescue
          'An unknown exception has occurred.'
        end
      end
    end
  end
end

Faraday::Response.register_middleware vetext_errors: CovidVaccine::Middleware::Response::Errors
