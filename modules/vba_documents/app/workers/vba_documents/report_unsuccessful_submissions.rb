# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class ReportUnsuccessfulSubmissions
    include Sidekiq::Worker

    def perform
      if Settings.vba_documents.report_enabled
        @to = Time.zone.now
        @from = @to.monday? ? 7.days.ago : 1.day.ago
        @consumers = VBADocuments::UploadSubmission.where(created_at: @from..@to).pluck(:consumer_name).uniq

        VBADocuments::UnsuccessfulReportMailer.build(totals, stuck, errored, @from, @to).deliver_now
      end
    end

    def errored
      VBADocuments::UploadSubmission.where(
        created_at: @from..@to,
        status: %w[error expired]
      ).order(:consumer_name, :status)
    end

    def stuck
      VBADocuments::UploadSubmission.where(
        created_at: @from..@to,
        status: 'uploaded'
      ).order(:consumer_name, :status)
    end

    def totals
      @consumers.map do |name|
        counts = VBADocuments::UploadSubmission.where(created_at: @from..@to, consumer_name: name).group(:status).count
        totals = counts.sum { |_k, v| v }
        error_rate = counts['error'] ? (100.0 / totals * counts['error']).round : 0
        expired_rate = counts['expired'] ? (100.0 / totals * counts['expired']).round : 0
        if totals.positive?
          {
            name => counts.merge(totals: totals,
                                 error_rate: "#{error_rate}%",
                                 expired_rate: "#{expired_rate}%")
          }
        end
      end
    end
  end
end
