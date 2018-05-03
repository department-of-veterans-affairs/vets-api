# frozen_string_literal: true

require 'evss/base_service'

module EVSS
  module GiBillStatus
    class Service < EVSS::Service
      configuration EVSS::GiBillStatus::Configuration

      OPERATING_ZONE = 'Eastern Time (US & Canada)'
      OPERATING_HOURS = {
        start: 6,
        end: 22,
        saturday_end: 19
      }.freeze

      def self.within_scheduled_uptime?
        current_time = Time.now.in_time_zone(OPERATING_ZONE)
        if current_time.saturday?
          (OPERATING_HOURS[:start]...OPERATING_HOURS[:saturday_end]).cover?(current_time.hour)
        else
          (OPERATING_HOURS[:start]...OPERATING_HOURS[:end]).cover?(current_time.hour)
        end
      end

      def self.retry_after_time
        current_time = Time.now.in_time_zone(OPERATING_ZONE)
        tz = ActiveSupport::TimeZone.new(OPERATING_ZONE)
        service_start_time = tz.parse(tz.today.to_s + ' 0' + OPERATING_HOURS[:start].to_s + ':00:00')

        return service_start_time.httpdate if current_time.hour < OPERATING_HOURS[:start]
        service_start_time.tomorrow.httpdate
      end

      def get_gi_bill_status
        raw_response = perform(:get, '')
        EVSS::GiBillStatus::GiBillStatusResponse.new(raw_response.status, raw_response)
      rescue Common::Client::Errors::ClientError => e
        response = OpenStruct.new(status: e.status, body: e.body)

        extra_context = { url: config.base_path, response: response }
        EVSS::GiBillStatus::GiBillStatusResponse.new(response.status, response)
      end
    end
  end
end
