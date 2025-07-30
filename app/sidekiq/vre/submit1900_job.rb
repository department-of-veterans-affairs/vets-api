# frozen_string_literal: true

require 'vets/shared_logging'
require 'vre/monitor'

module VRE
  class Submit1900Job
    include Sidekiq::Job
    include Vets::SharedLogging

    STATSD_KEY_PREFIX = 'worker.vre.submit_1900_job'
    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    RETRY = 16

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      VRE::Submit1900Job.trigger_failure_events(msg) if Flipper.enabled?(:vre_trigger_action_needed_email)
      StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
    end

    def perform(claim_id, encrypted_user)
      claim = SavedClaim::VeteranReadinessEmploymentClaim.find claim_id
      user = OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user)))
      claim.send_to_vre(user)
      StatsD.increment("#{STATSD_KEY_PREFIX}.success")
    rescue => e
      Rails.logger.warn("VRE::Submit1900Job failed, retrying...: #{e.message}")
      raise
    end

    def self.trigger_failure_events(msg)
      claim_id, encrypted_user = msg['args']
      claim = SavedClaim.find(claim_id)

      if Flipper.enabled?(:vre_use_new_vfs_notification_library)
        VRE::NotificationEmail.new(claim.id).deliver(:action_needed)
      else
        user = encrypted_user.present? ? OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user))) : nil
        email = claim.parsed_form['email'] || user.try(:va_profile_email)
        monitor = VRE::Monitor.new
        monitor.track_submission_exhaustion(msg, email)
        claim.send_failure_email(email) if claim.present?
      end
    end
  end
end
