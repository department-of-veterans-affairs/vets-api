# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DecisionReviewReportWeekly
    include ReportRecipientsReader
    include Sidekiq::Worker
    include Sidekiq::MonitoredWorker

    # Only retry for ~48 hours since the job is run weekly
    sidekiq_options retry: 16, unique_for: 48.hours

    def perform(to: Time.zone.now, from: 1.week.ago.beginning_of_day)
      if enabled?
        recipients = load_recipients(:report_weekly)
        if recipients.present?
          DecisionReviewMailer.build(date_from: from, date_to: to, friendly_duration: 'Weekly',
                                     recipients:).deliver_now
        end
      end
    end

    def retry_limits_for_notification
      [16]
    end

    def notify(retry_params)
      AppealsApi::Slack::Messager.new(retry_params, notification_type: :error_retry).notify!
    end

    private

    def enabled?
      Settings.modules_appeals_api.reports.weekly_decision_review.enabled && FeatureFlipper.send_email?
    end
  end
end
