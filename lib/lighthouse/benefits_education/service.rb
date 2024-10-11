# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'lighthouse/benefits_education/configuration'
require 'lighthouse/service_exception'
require 'lighthouse/benefits_education/response'

module BenefitsEducation
  class Service < Common::Client::Base
    include SentryLogging
    include Common::Client::Concerns::Monitoring

    configuration BenefitsEducation::Configuration

    STATSD_KEY_PREFIX = 'api.benefits_education'

    # TO-DO: Remove these constants after transition of LTS to 24/7 availability
    OPERATING_ZONE = 'Eastern Time (US & Canada)'
    OPERATING_HOURS = {
      start: 6,
      end: 22,
      saturday_end: 19
    }.freeze

    ##
    # @parameter [String] icn: icn of the Veteran requesting education benefits information
    # @return [BenefitsEducation::Service] a new instance of the service
    #
    def initialize(icn)
      @icn = icn
      raise ArgumentError, 'no ICN passed in for LH API request.' if icn.blank?

      super()
    end

    # Overriding inspect to avoid displaying icn (now considered to be PII)
    # in the response
    def inspect
      instance_variables_to_inspect = instance_variables - [:@icn]
      instance_variables_string = instance_variables_to_inspect.map do |var|
        "#{var}=#{instance_variable_get(var).inspect}"
      end.join(', ')
      "#<#{self.class}:#{object_id} #{instance_variables_string}>"
    end

    ##
    # Retrieve a veteran's Post-9/11 GI Bill Status
    # @return [String] A JSON string representing the veteran's GI Bill status.
    def get_gi_bill_status
      raw_response = begin
        config.get(@icn)
      rescue Breakers::OutageException => e
        raise e
      rescue => e
        handle_error(e, config.service_name, config.base_path)
      end
      BenefitsEducation::Response.new(raw_response.status, raw_response)
    end

    def handle_error(error, lighthouse_client_id, endpoint)
      Lighthouse::ServiceException.send_error(
        error,
        self.class.to_s.underscore,
        lighthouse_client_id,
        endpoint
      )
    end

    ##
    # TO-DO: Remove this method after transition of LTS to 24/7 availability
    #
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
    # TO-DO: Remove this method after transition of LTS to 24/7 availability
    #
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
    # TO-DO: Remove this method after transition of LTS to 24/7 availability
    #
    # @return [String] Next earliest date and time that the service will be available
    #
    def self.retry_after_time
      current_time = get_current_time
      tz = ActiveSupport::TimeZone.new(OPERATING_ZONE)
      service_start_time = tz.parse("#{tz.today} 0#{OPERATING_HOURS[:start]}:00:00")

      return service_start_time.httpdate if current_time.hour < OPERATING_HOURS[:start]

      service_start_time.tomorrow.httpdate
    end

    def self.get_current_time
      Time.now.in_time_zone(OPERATING_ZONE)
    end

    private_class_method :get_current_time
  end
end
