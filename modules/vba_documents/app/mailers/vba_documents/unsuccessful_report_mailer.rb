# frozen_string_literal: true

module VBADocuments
  class UnsuccessfulReportMailer < ApplicationMailer
    RECIPIENTS = %w[
      andrew.fichter@va.gov
      michael.bastos@oddball.io
      charley.stran@oddball.io
      alex.teal@oddball.io
      aubrey.suter@adhocteam.us
      trista.rowan@adhocteam.us
    ].freeze

    def build(unsuccessful_submissions, date_from, date_to)
      @unsuccessful_submissions = unsuccessful_submissions
      @date_from = date_from
      @date_to = date_to

      path = VBADocuments::Engine.root.join('app', 'mailers', 'vba_documents', 'views', 'unsuccessful_report.erb')
      template = File.read(path)

      mail(
        to: RECIPIENTS,
        subject: 'Benefits Intake Unsuccessful Submission Report',
        body: ERB.new(template).result(binding)
      )
    end
  end
end
