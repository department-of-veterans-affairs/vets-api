# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class ReportUnsuccessfulSubmissions
    include Sidekiq::Worker

    def perform
      if Settings.vba_documents.unsuccessful_report_enabled
        to = Time.zone.now
        from = to.monday? ? 7.days.ago : 1.day.ago
        errored_submissions = VBADocuments::UploadSubmission.where(
          created_at: from..to,
          status: %w[error expired]
        )
        stuck_submissions = VBADocuments::UploadSubmission.where(
          created_at: from..to,
          status: 'uploaded'
        )

        consumer_totals = VBADocuments::UploadSubmission.where(created_at: from..to).pluck(:consumer_name).uniq.map do |consumer_name|
          counts = VBADocuments::UploadSubmission.where(created_at: from..to, consumer_name: consumer_name).group(:status).count
          totals = counts.sum{|k,v| v }
          {
            consumer_name => counts.merge( totals: totals, 
                                           error_rate: "#{(100.0/totals*counts['error']).round}%", 
                                           expired_rate: "#{(100.0/totals*counts['expired']).round}%"
                                          )
          }
        end

        VBADocuments::UnsuccessfulReportMailer.build(consumer_totals, stuck_submissions, errored_submissions, from, to).deliver_now
      end
    end
  end
end
