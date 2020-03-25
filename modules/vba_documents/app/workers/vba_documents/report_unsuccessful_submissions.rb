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
        VBADocuments::UnsuccessfulReportMailer.build(errored_submissions, stuck_submissions, from, to).deliver_now
      end
    end
  end
end
