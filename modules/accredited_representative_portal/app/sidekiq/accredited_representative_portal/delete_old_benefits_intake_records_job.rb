# frozen_string_literal: true

require 'sidekiq'

module AccreditedRepresentativePortal
  class DeleteOldBenefitsIntakeRecordsJob
    include Sidekiq::Job

    sidekiq_options retry: false, queue: :default

    STATSD_KEY_PREFIX = 'worker.accredited_representative_portal.delete_old_benefits_intake_records'

    def perform
      return unless enabled?

      deleted_records = AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
                        .where('created_at <= ?', 60.days.ago)
                        .destroy_all

      deleted_count = deleted_records.size
      klass_name    = self.class.to_s

      StatsD.increment("#{STATSD_KEY_PREFIX}.count", deleted_count)

      # Consolidate info logging into one call
      message = "#{klass_name} deleted #{deleted_count} old BenefitsIntake records"
      Rails.logger.info(message)
    rescue => e
      error_class   = e.class
      error_message = e.message
      klass_name    = self.class.to_s

      StatsD.increment("#{STATSD_KEY_PREFIX}.error")

      # Consolidate error logging and slack alert
      error_log_message = "#{klass_name} perform exception: #{error_class} #{error_message}"
      Rails.logger.error(error_log_message)
      send_slack_alert(error_class, error_message, klass_name)
    end

    private

    def enabled?
      Flipper.enabled?(:delete_old_benefits_intake_records_job_enabled)
    end

    def send_slack_alert(error_class, error_message, klass_name)
      message = "[ALERT] #{klass_name} failed: #{error_class} - #{error_message}"
      if defined?(Slack::Notifier)
        Slack::Notifier.notify(message)
      else
        Rails.logger.warn("Slack::Notifier not defined; skipping Slack alert: #{error_class} #{error_message}")
      end
    rescue => e
      Rails.logger.error("Failed to send Slack alert: #{e.class} #{e.message}")
    end

    def self.rerun_missed!
      new.perform
    end
    private_class_method :rerun_missed!
  end
end
