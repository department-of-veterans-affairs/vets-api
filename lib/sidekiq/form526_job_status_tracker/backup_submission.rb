# frozen_string_literal: true

module Sidekiq
  module Form526JobStatusTracker
    module BackupSubmission
      # rubocop:disable Metrics/MethodLength
      def send_backup_submission_if_enabled(form526_submission_id:, job_class:, job_id:, error_class:,
                                            error_message:)
        submission_obj = Form526Submission.find(form526_submission_id)
        if Flipper.enabled?(:disability_compensation_production_tester,
                            OpenStruct.new({ flipper_id: submission_obj.user_uuid }))
          ::Rails.logger.info("send_backup_submission_if_enabled call skipped for submission #{form526_submission_id}")
          return
        end

        backup_job_jid = nil
        flipper_sym = :form526_backup_submission_temp_killswitch
        # Entry-point for backup 526 CMP submission
        #
        # Required criteria to send a backup 526 submission from here:
        # Enabled in settings and flipper
        # Is an overall submission and NOT an upload attempt
        # Does not have a valid claim ID (through RRD process or otherwise) (protect against dup submissions)
        # Does not have a backup submission ID (protect against dup submissions)
        # Does not have a submission ID (protect against dup submissions)
        # Does not have additional birls it is going to try and submit with
        send_backup_submission = Settings.form526_backup.enabled && Flipper.enabled?(flipper_sym) &&
                                 job_class == 'SubmitForm526AllClaim' &&
                                 submission_obj.submitted_claim_id.nil? &&
                                 (additional_birls = submission_obj.birls_ids_that_havent_been_tried_yet).empty? &&
                                 submission_obj.backup_submitted_claim_id.nil? &&
                                 submission_obj.submitted_claim_id.nil?

        if send_backup_submission
          backup_job_jid = Sidekiq::Form526BackupSubmissionProcess::Submit.perform_async(form526_submission_id)
          # send "Submitted" email without claim id here for backup path
          submission_obj.send_submitted_email("#{self.class}#send_backup_submission_if_enabled backup path")
        end
        vagov_id = JSON.parse(submission_obj.auth_headers_json)['va_eauth_service_transaction_id']
        log_message = {
          submission_id: form526_submission_id, job_id:, job_class:, error_class:, error_message:,
          remaining_birls: additional_birls, va_eauth_service_transaction_id: vagov_id
        }
        log_message['backup_job_id'] = backup_job_jid unless backup_job_jid.nil?
        ::Rails.logger.error('Form526 Exhausted or Errored (retryable-error-path)', log_message)
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
