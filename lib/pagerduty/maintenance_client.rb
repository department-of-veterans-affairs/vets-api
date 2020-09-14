# frozen_string_literal: true

require 'common/client/base'
require_relative 'service'
require_relative 'configuration'

module PagerDuty
  class MaintenanceClient < PagerDuty::Service
    configuration PagerDuty::Configuration

    def get_all(options = {})
      return [] if PagerDuty::Configuration.service_ids.blank? # require whitelisted services

      raw_mws = get_all_raw(options)
      convert(raw_mws)
    end

    private

    def get_all_raw(options = {})
      resp = get_raw(options)
      windows = resp['maintenance_windows']
      while resp['more']
        offset = resp['offset'] + resp['limit']
        resp = get_raw(options.merge('offset' => offset))
        windows += resp['maintenance_windows']
      end
      windows
    end

    def get_raw(options = {})
      query = {
        'offset' => 0,
        'filter' => 'open',
        'service_ids' => PagerDuty::Configuration.service_ids
      }.merge(options)
      perform(:get, 'maintenance_windows', query).body
    end

    def convert(raw_mws)
      result = []
      raw_mws.each do |mw|
        mw['services'].each do |svc|
          window = {
            pagerduty_id: mw['id'],
            external_service: PagerDuty::Configuration.service_map[svc['id']].to_s,
            start_time: Time.iso8601(mw['start_time']),
            end_time: Time.iso8601(mw['end_time']),
            description: mw['description'] ||= ''
          }
          result << window
        end
      end
      result
    end
  end
end
