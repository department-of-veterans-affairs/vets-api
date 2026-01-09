# frozen_string_literal: true

require 'sidekiq'

module AccreditedRepresentativePortal
  class DeleteOldBenefitsIntakeRecordsJob
    include Sidekiq::Job

    sidekiq_options retry: false, queue: :default

    STATSD_KEY_PREFIX = 'worker.accredited_representative_portal.delete_old_benefits_intake_records'

    def perform
      return unless enabled?

      deleted_count = perform_deletion
      handle_success(deleted_count)
    rescue => e
      ErrorHandler.new(self, e).call
    end

    private

    # Feature flag
    def enabled?
      Flipper.enabled?(:accredited_representative_portal_delete_benefits_intake)
    end

    # Deletes old records and returns the count
    def perform_deletion
      total = 0

      AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
        .where('delete_date <= ?', 60.days.ago)
        .find_each(batch_size: 1000) do |record|
          record.destroy
          total += 1
        end

      total
    end

    # Handle success in small helpers
    def handle_success(deleted_count)
      log_deletion(deleted_count)
      increment_stats(deleted_count)
    end

    def log_deletion(count)
      Rails.logger.info("#{self.class} deleted #{count} old BenefitsIntake records")
    end

    def increment_stats(count)
      StatsD.increment("#{STATSD_KEY_PREFIX}.count", count)
    end

    # ----- Error Handler -----
    class ErrorHandler
      def initialize(job, exception)
        @job = job
        @exception = exception
      end

      def call
        log_error
        increment_error
        notify_slack
      rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::ActiveRecordError, StandardError => e
        log_slack_failure(e)
      end

      private

      def log_error
        Rails.logger.error("#{@job.class} perform exception: #{exception_class} #{exception_message}")
      end

      def increment_error
        StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      end

      def notify_slack
        message = "[ALERT] #{@job.class} failed: #{exception_class} - #{exception_message}"

        if defined?(Slack::Notifier)
          Slack::Notifier.notify(message)
        else
          Rails.logger.warn("Slack::Notifier not defined; skipping #{exception_class} #{exception_message}")
        end
      end

      def log_slack_failure(exception)
        Rails.logger.error("Failed to send Slack alert: #{exception.class} #{exception.message}")
      end

      # Store repeated calls in locals
      def exception_class
        @exception_class ||= @exception.class
      end

      def exception_message
        @exception_message ||= @exception.message
      end
    end

    # Rerun helper
    def self.rerun_missed!
      new.perform
    end
    private_class_method :rerun_missed!
  end
end
