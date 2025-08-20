# frozen_string_literal: true

require 'vre/vre_monitor'

module VRE
  class VRESubmit1900Job
    include Sidekiq::Job
    include SentryLogging

    STATSD_KEY_PREFIX = 'worker.vre.submit_1900_job'
    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    RETRY = 16

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      VRE::VRESubmit1900Job.trigger_failure_events(msg)
    end

    def perform(claim_id, encrypted_user)
      claim = VRE::VREVeteranReadinessEmploymentClaim.find claim_id
      user = OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user)))
      claim.send_to_vre(user)
    rescue => e
      Rails.logger.warn("VRE::VRESubmit1900Job failed, retrying...: #{e.message}")
      raise
    end

    def self.trigger_failure_events(msg)
      monitor = VRE::VREMonitor.new
      claim_id, _encrypted_user = msg['args']
      claim = ::SavedClaim.find(claim_id)
      monitor.track_submission_exhaustion(msg, claim.email)
      claim.send_failure_email if claim.present?
    end
  end
end
