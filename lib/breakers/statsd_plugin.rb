# frozen_string_literal: true

module Breakers
  class StatsdPlugin
    def get_tags(request)
      tags = []
      if request
        tags.append("endpoint:#{filtered_endpoint_tag(request.url.path)}") if request.url&.path
        tags.append("method:#{request.method}") if request.method
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
      StatsD.increment(metric_base + status, 1, tags: tags)
      if response_env && response_env[:duration]
        StatsD.measure(metric_base + 'time', response_env[:duration], tags: tags)
      end
    end

    private

    def filtered_endpoint_tag(path)
      # replace identifiers with 'xxx'
      # this nasty-looking regex attempts to cover:
      # * (possibly negative) digit identifiers
      # * uuid's with or without dashes
      # * institution id's of form 111A2222 or 11A22222
      digit = /\-?\d+/
      contact_id = /\d{10}V\d{6}(%5ENI%5E200M%5EUSVHA)*/
      uuids = /[a-fA-F0-9]{8}(\-?[a-fA-F0-9]{4}){3}\-?[a-fA-F0-9]{12}/
      institution_ids = /[\dA-Z]{8}/
      provider_ids = /Providers\(\d{10}\)/
      v1_user_ids_1 = /[0-9a-f]{22}$/ # e.g. /api/v1/users/bb9c0f499977be68611151
      v1_user_ids_2 = /00u2[0-9a-zA-Z]{16}/ # e.g. /api/v1/users/00u2gskfa6kXUvU0N792

      r = %r{
        (\/)
        (#{digit}|#{contact_id}|#{uuids}|#{institution_ids}|#{provider_ids}|#{v1_user_ids_1}|#{v1_user_ids_2})
        (\/|$)
      }x

      path.gsub(r, '\1xxx\5')
    end
  end
end
