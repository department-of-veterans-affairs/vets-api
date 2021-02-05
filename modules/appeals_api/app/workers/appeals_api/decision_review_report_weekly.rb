# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DecisionReviewReportWeekly
    include Sidekiq::Worker

    def perform(to: Time.zone.now, from: 1.week.ago)
      if Settings.modules_appeals_api.report_enabled
        DecisionReviewMailer.build(date_from: from, date_to: to, friendly_duration: 'Weekly').deliver_now
      end
    end
  end
end
