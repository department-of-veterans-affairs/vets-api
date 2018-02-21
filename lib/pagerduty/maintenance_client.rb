# frozen_string_literal: true

require 'common/client/base'
require 'pagerduty/configuration'

module PagerDuty
  class MaintenanceClient < Common::Client::Base
    configuration PagerDuty::Configuration

    def get_all
      return [] if service_ids.blank? # require whitelisted services
      raw_mws = get_all_raw
      convert(raw_mws)
    end

    private

    def get_all_raw
      resp = get_raw
      windows = resp['maintenance_windows']
      while resp['more']
        offset = resp['offset'] + resp['limit']
        resp = get_raw(offset = offset)
        windows += resp['maintenance_windows']
      end
      windows
    end

    def get_raw(offset = 0)
      query = { 'offset' => offset,
                'filter' => 'open',
                'service_ids' => service_ids }
      perform(:get, 'maintenance_windows', query, headers).body
    end

    def convert(raw_mws)
      result = []
      raw_mws.each do |mw|
        mw['services'].each do |svc|
          window = {
            pagerduty_id: mw['id'],
            external_service: service_map[svc['id']].to_s,
            start_time: Time.iso8601(mw['start_time']),
            end_time: Time.iso8601(mw['end_time']),
            description: mw['description'] ||= ''
          }
          result << window
        end
      end
      result
    end

    def service_map
      Settings.maintenance.services&.to_hash&.invert || {}
    end

    def service_ids
      Settings.maintenance.services&.to_hash&.values || []
    end

    def headers
      { 'Authorization' => "Token token=#{Settings.maintenance.pagerduty_api_token}" }
    end
  end
end
