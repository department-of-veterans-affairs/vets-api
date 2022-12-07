# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DailyErrorReport
    include Sidekiq::Worker
    # Only retry for ~8 hours since the job is run daily
    sidekiq_options retry: 11, unique_for: 8.hours

    RECIPIENTS = ReportRecipientsReader.load_recipients(:error_report_daily).freeze

    def perform
      DailyErrorReportMailer.build(recipients: RECIPIENTS).deliver_now if enabled?
    end

    private

    def enabled?
      Settings.modules_appeals_api.reports.daily_error.enabled && FeatureFlipper.send_email?
    end
  end
end
