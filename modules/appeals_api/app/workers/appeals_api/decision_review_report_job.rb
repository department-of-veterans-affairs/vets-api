# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DecisionReviewReportJob
    include Sidekiq::Worker

    def perform
      if Settings.modules_appeals_api.report_enabled
        to = Time.zone.now
        from = to.monday? ? 7.days.ago : 1.day.ago

        DecisionReviewMailer.build(date_from: from, date_to: to).deliver_now
      end
    end
  end
end
