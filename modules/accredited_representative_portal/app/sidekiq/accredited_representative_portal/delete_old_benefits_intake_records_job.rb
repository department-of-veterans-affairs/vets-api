# frozen_string_literal: true

require 'sidekiq'

module AccreditedRepresentativePortal
  class DeleteOldBenefitsIntakeRecordsJob
    include Sidekiq::Job

    # This job is idempotent: deleting old records multiple times is safe
    # No retry needed, since all exceptions are logged and monitored
    sidekiq_options retry: false, queue: :default

    STATSD_KEY_PREFIX = 'worker.accredited_representative_portal.delete_old_benefits_intake_records'

    def perform
      return unless enabled?

      # Fully qualified class to avoid namespace issues
      deleted_records = AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
                        .where('created_at <= ?', 60.days.ago)
                        .destroy_all

      StatsD.increment("#{STATSD_KEY_PREFIX}.count", deleted_records.size)
      Rails.logger.info("#{self.class} deleted #{deleted_records.size} old BenefitsIntake records")
    rescue => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      Rails.logger.error("#{self.class} perform exception: #{e.class} #{e.message}")

      # Slack alert for immediate visibility to VA ARC OCTO team
      send_slack_alert(e)

      nil
    end

    private

    def enabled?
      Flipper.enabled?(:delete_old_benefits_intake_records_job_enabled)
    end

    def send_slack_alert(exception)
      # Ensure Slack is defined (stub in test if needed)
      if defined?(Slack::Notifier)
        Slack::Notifier.notify(
          "[ALERT] #{self.class} failed: #{exception.class} - #{exception.message}"
        )
      else
        Rails.logger.warn("Slack::Notifier not defined; skipping Slack alert: #{exception.class} #{exception.message}")
      end
    rescue => e
      # Avoid breaking the job if Slack fails
      Rails.logger.error("Failed to send Slack alert: #{e.class} #{e.message}")
    end

    # Rerun helper for manually retrying missed deletions
    # Usage: AccreditedRepresentativePortal::DeleteOldBenefitsIntakeRecordsJob.rerun_missed!
    def self.rerun_missed!
      new.perform
    end
    private_class_method :rerun_missed!
  end
end
