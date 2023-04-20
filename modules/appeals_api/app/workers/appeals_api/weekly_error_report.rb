# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'

# The "weekly" in the job name refers to its cadence, not the bound timeframe of records to report on.
# All errors are reported, as well as "stuck" records.
module AppealsApi
  class WeeklyErrorReport
    include ReportRecipientsReader
    include Sidekiq::Worker
    include Sidekiq::MonitoredWorker

    # Only retry for ~48 hours since the job is run weekly
    sidekiq_options retry: 16, unique_for: 48.hours

    def perform
      if enabled?
        recipients = load_recipients(:error_report_weekly)
        if recipients.present?
          WeeklyErrorReportMailer.build(friendly_duration: 'Weekly',
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
      FeatureFlipper.send_email? && Flipper.enabled?(:decision_review_weekly_error_report_enabled)
    end
  end
end
