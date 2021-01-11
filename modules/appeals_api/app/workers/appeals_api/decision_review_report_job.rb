# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DecisionReviewReportJob
    include Sidekiq::Worker

    def perform(to: Time.zone.now, from: (to.monday? ? 3.days.ago : 1.day.ago))
      if Settings.modules_appeals_api.report_enabled
        DecisionReviewMailer.build(date_from: from, date_to: to).deliver_now
      end
    end
  end
end
