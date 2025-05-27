# frozen_string_literal: true

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
      claim_id, encrypted_user = msg['args']
      claim = ::SavedClaim.find(claim_id)
      user = encrypted_user.present? ? OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user))) : nil
      email = claim.parsed_form['email'] || user.try(:va_profile_email)
      monitor.track_submission_exhaustion(msg, email)
      claim.send_failure_email(email) if claim.present?
    end
  end
end
