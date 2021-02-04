# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DailyErrorReport
    include Sidekiq::Worker

    def perform
      if Settings.modules_appeals_api.reports.daily_error.enabled
        DailyErrorReportMailer.build.deliver_now
      end
    end
  end
end
