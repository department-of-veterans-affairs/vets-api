# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DecisionReviewReportDaily
    include Sidekiq::Worker

    def perform(to: Time.zone.now, from: (to.monday? ? 3.days.ago : 1.day.ago))
      DecisionReviewMailer.build(date_from: from, date_to: to, friendly_duration: 'Daily').deliver_now if enabled?
    end

    private

    def enabled?
      Settings.modules_appeals_api.reports.decision_review.enabled
    end
  end
end
