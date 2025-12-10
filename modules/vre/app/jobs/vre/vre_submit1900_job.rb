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

    FORM_TYPE = '28-1900'
    FORM_TYPE_V2 = '28-1900-V2'

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
        form_type: [FORM_TYPE, FORM_TYPE_V2],
        created_at: threshold..
      )
      Rails.logger.info('VRE::VRESubmit1900Job - Duplicate Submission Check',
                        user_account_id: user_account.id,
                        submission_count: submissions.count,
                        duplicates_detected: submissions.count > 1,
                        threshold_hours:)

      StatsD.increment("#{STATSD_KEY_PREFIX}.duplicate_submission") if submissions.count > 1
    end

    # rubocop:disable Metrics/MethodLength
    def perform(claim_id, encrypted_user, submission_id = nil)
      if Flipper.enabled?(:vre_track_submissions) && submission_id
        submission = FormSubmission.find(submission_id)
        attempt = submission.form_submission_attempts.create!
        Rails.logger.info(
          'VRE::VRESubmit1900Job - Submission Attempt Created',
          claim_id:,
          submission_id:,
          submission_attempt_id: attempt.id
        )

      end

      begin
        # TODO: Change this to use new modular VRE claim class
        claim = SavedClaim::VeteranReadinessEmploymentClaim.find claim_id
        user = OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user)))
        claim.send_to_vre(user)
        StatsD.increment("#{STATSD_KEY_PREFIX}.success")

        if Flipper.enabled?(:vre_track_submissions) && submission_id
          attempt.succeed!
          Rails.logger.info(
            'VRE::VRESubmit1900Job - Submission Attempt Succeeded',
            num_attempts: submission.form_submission_attempts.count,
            user_account_id: claim.user_account&.id
          )
          duplicate_submission_check(claim.user_account)
        end
      rescue => e
        attempt&.fail! if Flipper.enabled?(:vre_track_submissions) && submission_id
        Rails.logger.warn("VRE::VRESubmit1900Job failed, retrying...: #{e.message}")
        raise
      end
    end
    # rubocop:enable Metrics/MethodLength

    def self.trigger_failure_events(msg)
      claim_id = msg['args'][0]
      claim = ::SavedClaim.find(claim_id)

      if Flipper.enabled?(:vre_use_new_vfs_notification_library)
        VRE::VREMonitor.new.track_submission_exhaustion(msg, claim)
      else
        VRE::Monitor.new.track_submission_exhaustion(msg, claim.email)
        claim.send_failure_email
      end
    end
  end
end
