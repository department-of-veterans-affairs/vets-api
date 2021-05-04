# frozen_string_literal: true

require 'evss/service'
require 'evss/gi_bill_status/configuration'
require 'evss/gi_bill_status/gi_bill_status_response'

module EVSS
  module GiBillStatus
    ##
    # Proxy Service for GIBS Caseflow.
    #
    # @example Create a service and fetching the status of a claim for a user
    #   gibs_response = GiBillStatus::Service.new.get_gi_bill_status
    #
    class Service < EVSS::Service
      configuration EVSS::GiBillStatus::Configuration

      OPERATING_ZONE = 'Eastern Time (US & Canada)'
      OPERATING_HOURS = {
        start: 6,
        end: 22,
        saturday_end: 19
      }.freeze

      ##
      # @return [Boolean] Is the current time within the system's scheduled uptime
      #
      def self.within_scheduled_uptime?
        current_time = get_current_time
        if current_time.saturday?
          (OPERATING_HOURS[:start]...OPERATING_HOURS[:saturday_end]).cover?(current_time.hour)
        else
          (OPERATING_HOURS[:start]...OPERATING_HOURS[:end]).cover?(current_time.hour)
        end
      end

      ##
      # @return [Integer] The number of seconds until scheduled system downtime begins
      #
      def self.seconds_until_downtime
        if within_scheduled_uptime?
          current_time = get_current_time
          end_hour = current_time.saturday? ? OPERATING_HOURS[:saturday_end] : OPERATING_HOURS[:end]
          tz = ActiveSupport::TimeZone.new(OPERATING_ZONE)
          service_end_time = tz.parse("#{tz.today} #{end_hour}:00:00")
          service_end_time - current_time
        else
          0
        end
      end

      ##
      # @return [String] Next earliest date and time that the service will be available
      #
      def self.retry_after_time
        current_time = get_current_time
        tz = ActiveSupport::TimeZone.new(OPERATING_ZONE)
        service_start_time = tz.parse("#{tz.today} 0#{OPERATING_HOURS[:start]}:00:00")

        return service_start_time.httpdate if current_time.hour < OPERATING_HOURS[:start]

        service_start_time.tomorrow.httpdate
      end

      ##
      # Retreive the status of a GIBS claim for a user
      #
      # @return [EVSS::GiBillStatus::GiBillStatusRestponse] A status response object containing
      # information from the endpoint
      #
      def get_gi_bill_status(additional_headers = {})
        raw_response = perform(:get, '', nil, additional_headers)
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
