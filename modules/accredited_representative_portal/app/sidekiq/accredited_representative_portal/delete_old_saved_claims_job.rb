# frozen_string_literal: true

require 'sidekiq'

module AccreditedRepresentativePortal
  class DeleteOldSavedClaimsJob
    include Sidekiq::Job

    sidekiq_options retry: false, queue: :default

    def perform
      return unless enabled?

      deleted_count = perform_deletion
      handle_success(deleted_count)
    rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::ActiveRecordError => e
      ErrorHandler.new(self, e).call
    end

    def statsd_key_prefix
      raise NotImplementedError
    end

    private

    def enabled?
      raise NotImplementedError
    end

    def scope
      raise NotImplementedError
    end

    def log_label
      raise NotImplementedError
    end

    def perform_deletion
      total = 0

      scope
        .where('delete_date <= ?', 60.days.ago)
        .find_each(batch_size: 1000) do |record|
          record.destroy
          total += 1
        end

      total
    end

    def handle_success(deleted_count)
      Rails.logger.info("#{self.class} deleted #{deleted_count} old #{log_label} records")
      StatsD.increment("#{statsd_key_prefix}.count", deleted_count)
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
        StatsD.increment("#{statsd_key_prefix}.error")
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
        @job.statsd_key_prefix
      end
    end
  end
end
