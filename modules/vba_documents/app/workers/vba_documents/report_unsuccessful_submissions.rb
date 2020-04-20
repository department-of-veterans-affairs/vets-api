# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class ReportUnsuccessfulSubmissions
    include Sidekiq::Worker

    def perform
      if Settings.vba_documents.unsuccessful_report_enabled
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
      )
    end

    def stuck
      VBADocuments::UploadSubmission.where(
        created_at: @from..@to,
        status: 'uploaded'
      )
    end

    def totals
      @consumers.map do |name|
        counts = VBADocuments::UploadSubmission.where(created_at: @from..@to, consumer_name: name).group(:status).count
        totals = counts.sum { |_k, v| v }
        {
          name => counts.merge(totals: totals,
                               error_rate: "#{(100.0 / totals * counts['error']).round}%",
                               expired_rate: "#{(100.0 / totals * counts['expired']).round}%")
        }
      end
    end
  end
end
