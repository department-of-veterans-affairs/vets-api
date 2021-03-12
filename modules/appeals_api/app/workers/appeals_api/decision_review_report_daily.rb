# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DecisionReviewReportDaily
    include Sidekiq::Worker
    # Only retry for ~8 hours since the job is run daily
    sidekiq_options retry: 11

    def perform(to: Time.zone.now, from: (to.monday? ? 3.days.ago.beginning_of_day : 1.day.ago.beginning_of_day))
      DecisionReviewMailer.build(date_from: from, date_to: to, friendly_duration: 'Daily').deliver_now if enabled?
    end

    private

    def enabled?
      Settings.modules_appeals_api.reports.decision_review.enabled
    end
  end
end
