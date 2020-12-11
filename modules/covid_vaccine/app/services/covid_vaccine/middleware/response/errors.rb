# frozen_string_literal: true

require 'common/exceptions'

module CovidVaccine
  module Middleware
    module Response
      class Errors < Faraday::Response::Middleware
        def on_complete(env)
          return if env.success?

          add_raven_extra_context(env)

          case env.status
          when 400
            parse_error(env, 400)
          when 500..510
            parse_error(env, 502)
          else
            raise Common::Exceptions::BackendServiceException, 'VA900'
          end
        end

        def add_raven_extra_context(env)
          Raven.extra_context(
            original_status: env.status,
            original_body: env.body,
            original_method: env.method,
            original_url: env.url
          )
        end

        def parse_error(env, status_to_render)
          raise Common::Exceptions::BackendServiceException.new(
            "VETEXT_#{status_to_render}",
            {
              detail: parse_detail(env.body),
              code: "VETEXT_#{env.status}",
              source: "#{env.method.upcase}: #{env.url}"
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
