# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class ReportUnsuccessfulSubmissions
    include Sidekiq::Worker

    def perform
      if Settings.vba_documents.unsuccessful_report_enabled
        from = 7.days.ago
        to = Time.zone.now
        submissions = VBADocuments::UploadSubmission.where(
          created_at: from..to,
          status: %w[error expired]
        )
        VBADocuments::UnsuccessfulReportMailer.build(submissions, from, to).deliver_now
      end
    end
  end
end
