# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class DailyErrorReport
    include Sidekiq::Worker

    def perform
      DailyErrorReportMailer.build.deliver_now if enabled?
    end

    private

    def enabled?
      Settings.modules_appeals_api.reports.daily_error.enabled
    end
  end
end
