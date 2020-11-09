# frozen_string_literal: true

module VBADocuments
  class UnsuccessfulReportMailer < ApplicationMailer
    RECIPIENTS = %w[
      david.mazik@va.gov
      michael.bastos@oddball.io
      ryan.link@oddball.io
      christopher.stone@libertyits.com
      valerie.hase@va.gov
      mark.greenburg@adhocteam.us
      premal.shah@va.gov
      lydia.vian@thunderyard.com
      joshua.jennings@libertyits.com
      cristopher.shupp@libertyits.com
      gregory.bowman@libertyits.com
      zachary.goldfine@va.gov
    ].freeze

    def build(consumer_totals, pending_submissions, unsuccessful_submissions, date_from, date_to)
      @consumer_totals = consumer_totals
      @pending_submissions = pending_submissions
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
