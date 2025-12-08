# frozen_string_literal: true

require 'vre/vre_monitor'
require 'vre/monitor'

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

    def duplicate_submission_check(user_account)
      return nil unless user_account

      # query for other formsubmission records for the same user in XXX hours
      threshold_hours = Settings.veteran_readiness_and_employment.duplicate_submission_threshold_hours || 24
      threshold = threshold_hours.hours.ago
      submissions = user_account.form_submissions.where(
        form_type: SavedClaim::VeteranReadinessEmploymentClaim::FORM,
        created_at: threshold..
      )

      if submissions.count > 1
        Rails.logger.warn(
          "Duplicate VRE 1900 submissions detected for user_account #{user_account.id}:" \
          "#{submissions.count} submissions in last #{threshold_hours} hours"
        )
        StatsD.increment("#{STATSD_KEY_PREFIX}.duplicate_submission")
      end
    end

    def perform(claim_id, encrypted_user, submission_attempt_id = nil)
      # TODO: Change this to use new modular VRE claim class
      claim = SavedClaim::VeteranReadinessEmploymentClaim.find claim_id
      user = OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user)))
      claim.send_to_vre(user)
      StatsD.increment("#{STATSD_KEY_PREFIX}.success")

      if Flipper.enabled?(:vre_track_submissions) && submission_attempt_id
        submission_attempt = FormSubmissionAttempt.find(submission_attempt_id)

        if submission_attempt
          form_submission = FormSubmission.create!(
            saved_claim: claim,
            form_type: claim.form_id,
            user_account: claim.user_account,
            form_submission_attempt_id: submission_attempt_id
          )

          submission_attempt.form_submission = form_submission
          submission_attempt.save!
          submission_attempt.succeed!
          duplicate_submission_check(claim.user_account)
        end
      end
    rescue => e
      Rails.logger.warn("VRE::VRESubmit1900Job failed, retrying...: #{e.message}")
      raise
    end

    def self.trigger_failure_events(msg)
      claim_id = msg['args'][0]
      claim = ::SavedClaim.find(claim_id)

      submission_attempt_id = msg['args'][2]

      if Flipper.enabled?(:vre_use_new_vfs_notification_library)
        VRE::VREMonitor.new.track_submission_exhaustion(msg, claim)
      else
        VRE::Monitor.new.track_submission_exhaustion(msg, claim.email)
        claim.send_failure_email
      end

      if Flipper.enabled?(:vre_track_submissions) && submission_attempt_id
        form_submission_attempt = FormSubmissionAttempt.find submission_attempt_id
        form_submission_attempt.fail! if form_submission_attempt
      end
    end
  end
end
