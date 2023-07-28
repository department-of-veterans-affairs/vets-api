# frozen_string_literal: true

require 'sidekiq'
require 'vba_documents/monthly_stats_generator'

module VBADocuments
  class ReportMonthlySubmissions
    include Sidekiq::Worker
    include Sidekiq::MonitoredWorker

    # Only retry for ~3 days since the job is run monthly
    sidekiq_options retry: 17, unique_for: 1.month

    def perform
      return unless Settings.vba_documents.monthly_report

      generate_prior_month_stats

      prior_twelve_months_stats = []

      12.times do |i|
        reporting_date = (i + 1).months.ago
        prior_twelve_months_stats << stored_month_stats(reporting_date.month, reporting_date.year)
      end

      VBADocuments::MonthlyReportMailer.build(prior_twelve_months_stats).deliver_now
    end

    def retry_limits_for_notification
      # Notify at 1 day, 3 days
      [14, 17]
    end

    def notify(retry_params)
      VBADocuments::Slack::Messenger.new(retry_params).notify!
    end

    private

    def generate_prior_month_stats
      VBADocuments::MonthlyStatsGenerator.new(month: 1.month.ago.month, year: 1.month.ago.year)
                                         .generate_and_save_stats
    end

    def stored_month_stats(month, year)
      VBADocuments::MonthlyStat.find_by(month:, year:)
    end
  end
end
