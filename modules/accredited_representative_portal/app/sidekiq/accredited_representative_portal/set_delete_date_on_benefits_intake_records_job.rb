# frozen_string_literal: true

require 'sidekiq'

module AccreditedRepresentativePortal
  class SetDeleteDateOnBenefitsIntakeRecordsJob
    include Sidekiq::Job

    STATSD_KEY_PREFIX = 'worker.accredited_representative_portal.mark_delete_benefits_intake_records'
    sidekiq_options retry: false, queue: :default

    def perform
      marked_deleted_count = perform_mark_for_deletion
      handle_success(marked_deleted_count)
    rescue => e
      ErrorHandler.new(self, e).call
    end

    private

    def delete_date
      60.days.from_now
    end

    def scope
      AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
    end

    def log_label
      'BenefitsIntake'
    end

    def perform_mark_for_deletion
      total = 0

      scope
        .where(delete_date: nil)
        .joins(:form_submissions)
        .joins(
          'INNER JOIN form_submission_attempts ON form_submission_attempts.form_submission_id' \
          ' = form_submissions.id AND form_submission_attempts.aasm_state IN ('vbms', 'manually')'
        ).find_each(batch_size: 1000) do |record|
          # rubocop:disable Rails/SkipsModelValidations
          record.update_columns(delete_date:)
          # rubocop:enable Rails/SkipsModelValidations
          total += 1
        end

      total
    end

    def handle_success(deleted_count)
      Rails.logger.info(
        "#{self.class} marked #{deleted_count} old #{log_label} records for deletion on #{delete_date}"
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.count", deleted_count)
    end

    # ----- Error handler -----
    class ErrorHandler
      def initialize(job, exception)
        @job = job
        @exception = exception
      end

      def call
        log_error
        increment_error
        notify_slack
      rescue
        log_slack_failure
      end

      private

      def log_error
        Rails.logger.error("#{job_class} perform exception: #{exception_class} #{exception_message}")
        Rails.logger.error(formatted_backtrace)
      end

      def increment_error
        StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      end

      def notify_slack
        VBADocuments::Slack::Messenger
          .new(slack_payload)
          .notify!
      end

      def log_slack_failure
        Rails.logger.error("Failed to send Slack alert for #{exception_class} #{exception_message}")
      end

      # ---- Memoized helpers ----
      def job_class
        @job.class
      end

      def exception_class
        @exception.class
      end

      def exception_message
        @exception.message
      end

      def formatted_backtrace
        Array(@exception.backtrace).join("\n")
      end

      def slack_payload
        {
          class: job_class.name,
          alert: "[ALERT] #{job_class} failed: #{exception_class} - #{exception_message}",
          details: formatted_backtrace.gsub(Rails.root.to_s, '[APP_ROOT]')
        }
      end

      def statsd_key_prefix
        @job.class::STATSD_KEY_PREFIX
      end
    end
  end
end
