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

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      VRE::VRESubmit1900Job.trigger_failure_events(msg)
      StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
    end

    def duplicate_submission_check(user_account)
      return nil unless user_account

      # Query for form submissions by this user within the configured threshold window (default 24 hours)
      threshold_hours = Settings.veteran_readiness_and_employment.duplicate_submission_threshold_hours.to_i
      threshold_hours = 24 unless threshold_hours.positive?
      submissions = user_account.form_submissions.where(form_type: FORM_TYPE,
                                                        created_at: threshold_hours.hours.ago..)
      submissions_data = submissions.pluck(:id, :created_at).map { |id, created_at| { id:, created_at: } }
      submissions_count = submissions.count
      duplicates_detected = submissions_count > 1

      log_payload = { user_account_id: user_account.id, submissions_count:,
                      duplicates_detected:, threshold_hours:, submissions_data: }

      log_message = 'VRE::VRESubmit1900Job - Duplicate Submission Check'

      if duplicates_detected
        Rails.logger.warn(log_message, log_payload)
        StatsD.increment("#{STATSD_KEY_PREFIX}.duplicate_submission")
      else
        Rails.logger.info(log_message, log_payload)
      end
    end

    def perform(claim_id, encrypted_user, submission_id = nil)
      submission, attempt = setup_submission_tracking(claim_id, submission_id)

      begin
        # TODO: Change this to use new modular VRE claim class
        claim = SavedClaim::VeteranReadinessEmploymentClaim.find(claim_id)
        user = OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user)))
        claim.send_to_vre(user)
        StatsD.increment("#{STATSD_KEY_PREFIX}.success")

        if submission && attempt
          Rails.logger.info('VRE::VRESubmit1900Job - Submission Attempt Succeeded',
                            claim_id:, submission_id:, submission_attempt_id: attempt.id,
                            num_attempts: submission.form_submission_attempts.size,
                            user_account_id: claim.user_account&.id)
          duplicate_submission_check(claim.user_account)
        end
      rescue => e
        Rails.logger.warn('VRE::VRESubmit1900Job failed, retrying...',
                          claim_id:, submission_id:, error_class: e.class.name, error_message: e.message)

        attempt.fail if submission && attempt
        raise
      end
    end

    def self.trigger_failure_events(msg)
      claim_id = msg['args'][0]
      claim = ::SavedClaim.find(claim_id)
      VRE::VREMonitor.new.track_submission_exhaustion(msg, claim)
    end

    private

    def setup_submission_tracking(claim_id, submission_id)
      return [nil, nil] unless submission_id

      begin
        submission = FormSubmission.find(submission_id)
        attempt = submission.form_submission_attempts.create!
        Rails.logger.info(
          'VRE::VRESubmit1900Job - Submission Attempt Created',
          claim_id:, submission_id:, submission_attempt_id: attempt.id
        )
        [submission, attempt]
      rescue => e
        Rails.logger.error(
          'VRE::VRESubmit1900Job - Submission Attempt Creation Failed - continuing without tracking',
          claim_id:, submission_id:, error_class: e.class.name, errors: e.message
        )
        [nil, nil]
      end
    end
  end
end
