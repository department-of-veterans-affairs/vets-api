# frozen_string_literal: true
module Breakers
  class StatsdPlugin
    def on_outage_begin(outage)
      StatsD.gauge("api.external_service.#{outage.service.name}.*.up", 0)
    end

    def on_outage_end(outage)
      StatsD.gauge("api.external_service.#{outage.service.name}.*.up", 1)
    end

    def on_error(service, _request_env, _response_env)
      StatsD.increment("api.external_http_request.#{service.name}.failed", 1)
    end

    def on_success(service, _request_env, response_env)
      StatsD.increment("api.external_http_request.#{service.name}.success", 1)
      StatsD.measure("api.external_http_request.#{service.name}.time", response_env[:duration])
    end
  end
end
