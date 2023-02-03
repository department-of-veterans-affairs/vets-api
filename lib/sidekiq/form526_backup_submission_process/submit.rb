# frozen_string_literal: true

require 'sidekiq/form526_backup_submission_process/processor'

module Sidekiq
  module Form526BackupSubmissionProcess
    class Form526BackgroundLoader
      extend ActiveSupport::Concern
      include Sidekiq::Worker
      sidekiq_options retry: false

      def perform(id)
        Processor.new(id, get_upload_location_on_instantiation: false,
                          ignore_expiration: true).upload_pdf_submission_to_s3
      end
    end

    class Submit
      extend ActiveSupport::Concern
      include SentryLogging
      include Sidekiq::Worker
      sidekiq_options retry: 0

      def perform(form526_submission_id)
        return unless Settings.form526_backup.enabled

        job_status = Form526JobStatus.create!(job_class: 'BackupSubmission', status: 'pending',
                                              form526_submission_id: form526_submission_id, job_id: jid)
        begin
          Processor.new(form526_submission_id).process!
          job_status.update(status: Form526JobStatus::STATUS[:success])
        rescue => e
          ::Rails.logger.error(
            message: "FORM526 BACKUP SUMBISSION FAILURE. Investigate immedietly: #{e.message}.",
            backtrace: e.backtrace,
            submission_id: form526_submission_id
          )
          bgjob_errors = job_status.bgjob_errors || {}
          bgjob_errors.merge!(error_hash_for_job_status(e))
          job_status.update(status: Form526JobStatus::STATUS[:exhausted], bgjob_errors: bgjob_errors)
          raise e
        end
      end

      private

      def error_hash_for_job_status(e)
        timestamp = Time.zone.now
        {
          "#{timestamp.to_i}": {
            caller_method: __method__.to_s,
            error_class: e.class.to_s,
            error_message: e.message,
            timestamp: timestamp
          }
        }
      end
    end
  end
end
