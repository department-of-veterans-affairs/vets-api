# frozen_string_literal: true
module Breakers
  class StatsdPlugin
    def get_tags(request)
      tags = []
      if request
        if request.url && request.url.path
          # replace identifiers with 'xxx'
          # this nasty-looking regex attempts to cover digit identifiers and uuid's with or without dashes
          r = %r{(\/)(\d+|[a-fA-F0-9]{8}(\-?[a-fA-F0-9]{4}){3}\-?[a-fA-F0-9]{12})(\/|$)}
          endpoint = request.url.path.gsub(r, '\1xxx\4')
          tags.append("endpoint:#{endpoint}")
        end

        tags.append("method:#{request.method}") if request.method
      end
      tags
    end

    def on_error(service, request_env, response_env)
      send_metric('failed', service, request_env, response_env)
    end

    def on_success(service, request_env, response_env)
      send_metric('success', service, request_env, response_env)
    end

    def send_metric(status, service, request_env, response_env)
      tags = get_tags(request_env)
      metric_base = "api.external_http_request.#{service.name}."
      StatsD.increment(metric_base + status, 1, tags: tags)
      if response_env && response_env[:duration]
        StatsD.measure(metric_base + 'time', response_env[:duration], tags: tags)
      end
    end
  end
end
