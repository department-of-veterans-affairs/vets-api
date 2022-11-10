# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class WeeklyErrorReport
    include Sidekiq::Worker
    # Only retry for ~48 hours since the job is run weekly
    sidekiq_options retry: 16, unique_for: 48.hours

    def perform(to: Time.zone.now, from: 1.week.ago.beginning_of_day)
      recipients = Settings.modules_appeals_api.reports.weekly_error.recipients
      if enabled?
        DecisionReviewMailer.build(date_from: from, date_to: to, friendly_duration: 'Weekly',
                                   recipients: recipients).deliver_now
      end
    end

    private

    def enabled?
      Settings.modules_appeals_api.reports.weekly_error.enabled &&
        FeatureFlipper.send_email? && Flipper.enabled?(:decision_review_weekly_error_report_enabled)
    end
  end
end
