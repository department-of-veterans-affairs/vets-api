# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DailyErrorReport
    include Sidekiq::Worker

    def perform
      DailyErrorReportMailer.build.deliver_now if Settings.modules_appeals_api.reports.daily_error.enabled
    end
  end
end
