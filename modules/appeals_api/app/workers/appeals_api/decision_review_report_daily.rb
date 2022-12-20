# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DecisionReviewReportDaily
    include ReportRecipientsReader
    include Sidekiq::Worker
    # Only retry for ~8 hours since the job is run daily
    sidekiq_options retry: 11, unique_for: 8.hours

    def perform(to: Time.zone.now, from: (to.monday? ? 3.days.ago.beginning_of_day : 1.day.ago.beginning_of_day))
      if enabled?
        recipients = load_recipients(:report_daily)
        if recipients.present?
          DecisionReviewMailer.build(date_from: from, date_to: to, friendly_duration: 'Daily',
                                     recipients: recipients).deliver_now
        end
      end
    end

    private

    def enabled?
      Settings.modules_appeals_api.reports.daily_decision_review.enabled && FeatureFlipper.send_email?
    end
  end
end
