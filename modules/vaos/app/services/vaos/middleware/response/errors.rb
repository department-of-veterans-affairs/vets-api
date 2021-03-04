# frozen_string_literal: true

module VAOS
  module Middleware
    module Response
      class Errors < Faraday::Response::Middleware
        STATSD_KEY_PREFIX = 'api.vaos.va_mobile.response'

        def on_complete(env)
          statsd_increment("#{STATSD_KEY_PREFIX}.total", env)
          return if env.success?

          statsd_increment("#{STATSD_KEY_PREFIX}.fail", env)
          Raven.extra_context(vamf_status: env.status, vamf_body: env.body, vamf_url: env.url)
          raise VAOS::Exceptions::BackendServiceException, env
        end

        private

        def statsd_increment(key, env)
          StatsDMetric.new(key: key).save
          tags = [
            "method:#{env.method.upcase}",
            "url:#{StringHelpers.filtered_endpoint_tag(env.url.path)}",
            "http_status:#{env.status}"
          ]
          StatsD.increment(key, tags: tags)
        end
      end
    end
  end
end

Faraday::Response.register_middleware vaos_errors: VAOS::Middleware::Response::Errors
