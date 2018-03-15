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
        byebug
        current_time = Time.now.in_time_zone(OPERATING_ZONE)
        if current_time.saturday?
          return current_time.hour > OPERATING_HOURS[:start] && current_time.hour < OPERATING_HOURS[:saturday_end]
        else
          return current_time.hour > OPERATING_HOURS[:start] && current_time.hour < OPERATING_HOURS[:end]
        end
      end

      def self.retry_after_time
        current_time = Time.now.in_time_zone(OPERATING_ZONE)
        six_am = Time.parse('0' + OPERATING_HOURS[:start].to_s + ':00:00').in_time_zone(OPERATING_ZONE)
        return six_am.httpdate if current_time.hour < OPERATING_HOURS[:start]
        return six_am.tomorrow.httpdate
      end

      def get_gi_bill_status
        raw_response = perform(:get, '')
        EVSS::GiBillStatus::GiBillStatusResponse.new(raw_response.status, raw_response)
      rescue Common::Client::Errors::ClientError => e
        response = OpenStruct.new(status: e.status, body: e.body)

        extra_context = { url: config.base_path, response: response }
        log_exception_to_sentry(e, extra_context)
        EVSS::GiBillStatus::GiBillStatusResponse.new(response.status, response)
      end
    end
  end
end
