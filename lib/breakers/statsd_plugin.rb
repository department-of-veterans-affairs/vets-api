# frozen_string_literal: true

module Breakers
  class StatsdPlugin
    def get_tags(upstream_request)
      source_app = RequestStore.store.dig('additional_request_attributes', 'source')

      tags = []
      if upstream_request
        if upstream_request.url&.path
          tags.append("endpoint:#{StringHelpers.filtered_endpoint_tag(upstream_request.url.path)}")
        end
        tags.append("method:#{upstream_request.method}") if upstream_request.method
        tags.append("source:#{source_app}") if source_app
      end
      tags
    end

    def on_error(service, request_env, response_env)
      send_metric('failed', service, request_env, response_env)
    end

    def on_skipped_request(service)
      send_metric('skipped', service, nil, nil)
    end

    def on_success(service, request_env, response_env)
      send_metric('success', service, request_env, response_env)
    end

    def send_metric(status, service, request_env, response_env)
      tags = get_tags(request_env)
      metric_base = "api.external_http_request.#{service.name}."
      StatsD.increment(metric_base + status, 1, tags:)
      StatsD.measure("#{metric_base}time", response_env[:duration], tags:) if response_env && response_env[:duration]
    end
  end
end
