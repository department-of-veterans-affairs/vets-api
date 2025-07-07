# frozen_string_literal: true

require 'vre/notification_email'
require 'zero_silent_failures/monitor'
require 'logging/base_monitor'

module VRE
  class VREMonitor < ::Logging::BaseMonitor
    # statsd key for api
    CLAIM_STATS_KEY = 'vre-application'
    # statsd key for initial sidekiq
    SUBMISSION_STATS_KEY = 'worker.vre.submit_1900_job'

    attr_reader :tags

    def initialize
      super('vre-application')
      @tags = ["form_id:#{form_id}"]
    end

    private

    ##
    # Module application name used for logging
    # @return [String]
    def service_name
      'vre-application'
    end

    #
    # Stats key for DD
    # @return [String]
    def claim_stats_key
      CLAIM_STATS_KEY
    end

    ##
    # Stats key for Sidekiq DD logging
    # @return [String]
    def submission_stats_key
      SUBMISSION_STATS_KEY
    end

    ##
    # Class name for log messages
    # @return [String]
    def name
      self.class.name
    end

    ##
    # @return [String]
    def form_id
      VRE::FORM_ID
    end

    ##
    # Class name for notification email
    # @return [Class]
    def send_email(claim_id, email_type)
      VRE::NotificationEmail.new(claim_id).deliver(email_type)
    end

    def track_submission_exhaustion(msg, email = nil, claim: nil, user: nil)
     StatsD.increment("#{SUBMISSION_STATS_KEY}.exhausted")
      Rails.logger.error(
        "Failed all retries on VRE::VreSubmit1900Job, last error: #{msg['error_message']}"
      )
    end  
  end
end
