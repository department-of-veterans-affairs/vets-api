# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DailyErrorReport
    include ReportRecipientsReader
    include Sidekiq::Worker
    # Only retry for ~8 hours since the job is run daily
    sidekiq_options retry: 11, unique_for: 8.hours

    def perform
      if enabled?
        recipients = load_recipients(:error_report_daily)
        DailyErrorReportMailer.build(recipients: recipients).deliver_now if recipients.present?
      end
    end

    private

    def enabled?
      Settings.modules_appeals_api.reports.daily_error.enabled && FeatureFlipper.send_email?
    end
  end
end
