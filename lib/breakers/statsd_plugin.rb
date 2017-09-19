# frozen_string_literal: true
module Breakers
  class StatsdPlugin
    def get_tags(request)
      tags = []
      if request && request.url.path
        # replace identifiers with 'xxx'
        endpoint = request.url.path.gsub(%r{(\/)(\d+)(\/?)}, '\1xxx\3')
        tags.append("endpoint:#{endpoint}")
      end
    end

    def on_error(service, request_env, _response_env)
      tags = get_tags(request_env)
      StatsD.increment("api.external_http_request.#{service.name}.failed", 1, tags: tags)
    end

    def on_success(service, request_env, response_env)
      tags = get_tags(request_env)
      StatsD.increment("api.external_http_request.#{service.name}.success", 1, tags: tags)
      StatsD.measure("api.external_http_request.#{service.name}.time", response_env[:duration], tags: tags)
    end
  end
end
