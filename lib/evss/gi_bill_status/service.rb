# frozen_string_literal: true

require 'evss/base_service'

module EVSS
  module GiBillStatus
    class Service < EVSS::Service
      configuration EVSS::GiBillStatus::Configuration

      def self.within_scheduled_uptime?
        current_time = Time.now.in_time_zone('Eastern Time (US & Canada)')
        if current_time.saturday?
          return current_time.hour > 6 && current_time.hour < 19
        else
          return current_time.hour > 6 && current_time.hour < 22
        end
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
