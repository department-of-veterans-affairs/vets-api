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
        current_time = get_current_time
        if current_time.saturday?
          (OPERATING_HOURS[:start]...OPERATING_HOURS[:saturday_end]).cover?(current_time.hour)
        else
          (OPERATING_HOURS[:start]...OPERATING_HOURS[:end]).cover?(current_time.hour)
        end
      end

      def self.seconds_until_downtime
        if within_scheduled_uptime?
          current_time = get_current_time
          end_hour = current_time.saturday? ? OPERATING_HOURS[:saturday_end] : OPERATING_HOURS[:end]
          tz = ActiveSupport::TimeZone.new(OPERATING_ZONE)
          service_end_time = tz.parse(tz.today.to_s + ' ' + end_hour.to_s + ':00:00')
          service_end_time - current_time
        else
          0
        end
      end

      def self.retry_after_time
        current_time = get_current_time
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
        EVSS::GiBillStatus::GiBillStatusResponse.new(response.status, response)
      end

      def self.get_current_time
        Time.now.in_time_zone(OPERATING_ZONE)
      end

      private_class_method :get_current_time
    end
  end
end
