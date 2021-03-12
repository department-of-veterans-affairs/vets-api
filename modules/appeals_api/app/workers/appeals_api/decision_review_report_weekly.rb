# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DecisionReviewReportWeekly
    include Sidekiq::Worker
    # Only retry for ~48 hours since the job is run weekly
    sidekiq_options retry: 16

    def perform(to: Time.zone.now, from: 1.week.ago.beginning_of_day)
      DecisionReviewMailer.build(date_from: from, date_to: to, friendly_duration: 'Weekly').deliver_now if enabled?
    end

    private

    def enabled?
      Settings.modules_appeals_api.reports.decision_review.enabled
    end
  end
end
