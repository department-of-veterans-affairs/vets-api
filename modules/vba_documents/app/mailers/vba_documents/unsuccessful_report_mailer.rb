# frozen_string_literal: true

module VBADocuments
  class UnsuccessfulReportMailer < ApplicationMailer
    RECIPIENTS = %w[
      andrew.fichter@va.gov
      michael.bastos@oddball.io
      charley.stran@oddball.io
      ryan.link@oddball.io
      kelly@adhocteam.us
      emily@oddball.io
      valerie.hase@va.gov
      mark.greenburg@adhocteam.us
      premal.shah@va.gov
      dan.hinze@adhocteam.us
      emily.goodrich@oddball.io
    ].freeze

    def build(consumer_totals, stuck_submissions, unsuccessful_submissions, date_from, date_to)
      @consumer_totals = consumer_totals
      @stuck_submissions = stuck_submissions
      @unsuccessful_submissions = unsuccessful_submissions
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
      body = ERB.new(template).result(binding)

      mail(
        to: RECIPIENTS,
        subject: 'Benefits Intake Unsuccessful Submission Report',
        body: body
      )
    end
  end
end
