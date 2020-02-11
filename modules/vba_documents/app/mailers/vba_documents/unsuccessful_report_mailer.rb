# frozen_string_literal: true

module VBADocuments
  class UnsuccessfulReportMailer < ApplicationMailer
    RECIPIENTS = %w[
      andrew.fichter@va.gov
      michael.bastos@oddball.io
      charley.stran@oddball.io
      ryan.link@oddball.io
      kelly@adhocteam.us
      ed.mangimelli@adhocteam.us
      emily@oddball.io
      valerie.hase@va.gov
    ].freeze

    def build(unsuccessful_submissions, stuck_submissions, date_from, date_to)
      @unsuccessful_submissions = unsuccessful_submissions
      @stuck_submissions = stuck_submissions
      @date_from = date_from
      @date_to = date_to

      path = VBADocuments::Engine.root.join(
        'app',
        'views',
        'vba_documents',
        'unsuccessful_report_mailer',
        'unsuccessful_report.html.erb'
      )
      template = File.read(path)

      mail(
        to: RECIPIENTS,
        subject: 'Benefits Intake Unsuccessful Submission Report',
        body: ERB.new(template).result(binding)
      )
    end
  end
end
