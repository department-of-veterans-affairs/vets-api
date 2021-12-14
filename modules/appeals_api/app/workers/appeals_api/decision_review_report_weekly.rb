# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DecisionReviewReportWeekly
    include Sidekiq::Worker
    # Only retry for ~48 hours since the job is run weekly
    sidekiq_options retry: 16

    def perform(to: Time.zone.now, from: 1.week.ago.beginning_of_day)
      recipients = Settings.modules_appeals_api.reports.weekly_decision_review.recipients
      if enabled?
        DecisionReviewMailer.build(date_from: from, date_to: to, friendly_duration: 'Weekly',
                                   recipients: recipients).deliver_now
      end
    end

    private

    def enabled?
      Settings.modules_appeals_api.reports.weekly_decision_review.enabled && FeatureFlipper.send_email?
    end
  end
end
