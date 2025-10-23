# frozen_string_literal: true

require 'vre/vre_monitor'

module VRE
  class VRESubmit1900Job
    include Sidekiq::Job

    STATSD_KEY_PREFIX = 'worker.vre.vre_submit_1900_job'
    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    RETRY = 16

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      VRE::VRESubmit1900Job.trigger_failure_events(msg)
      StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
    end

    def perform(claim_id, encrypted_user)
      # TODO: Change this to use new modular VRE claim class
      claim = SavedClaim::VeteranReadinessEmploymentClaim.find claim_id
      user = OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user)))
      claim.send_to_vre(user)
      StatsD.increment("#{STATSD_KEY_PREFIX}.success")
    rescue => e
      Rails.logger.warn("VRE::VRESubmit1900Job failed, retrying...: #{e.message}")
      raise
    end

    def self.trigger_failure_events(msg)
      claim_id = msg['args'][0]
      claim = ::SavedClaim.find(claim_id)
      VRE::VREMonitor.new.track_submission_exhaustion(msg, claim)
      claim.send_failure_email if claim.present?
    end
  end
end
