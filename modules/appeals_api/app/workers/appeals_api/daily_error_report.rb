# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'

# This report will only result in an email if there are errored records to report on.
# While the DecisionReviewReportDaily will also have this data, having it as a separate email makes
# filtering for it in your email client easier.
module AppealsApi
  class DailyErrorReport
    include ReportRecipientsReader
    include Sidekiq::Worker
    include Sidekiq::MonitoredWorker

    # Only retry for ~8 hours since the job is run daily
    sidekiq_options retry: 11, unique_for: 8.hours

    def perform
      if enabled?
        recipients = load_recipients(:error_report_daily)
        DailyErrorReportMailer.build(recipients:).deliver_now if recipients.present?
      end
    end

    def retry_limits_for_notification
      [11]
    end

    def notify(retry_params)
      AppealsApi::Slack::Messager.new(retry_params, notification_type: :error_retry).notify!
    end

    private

    def enabled?
      Flipper.enabled?(:decision_review_daily_error_report_enabled) && FeatureFlipper.send_email?
    end
  end
end
