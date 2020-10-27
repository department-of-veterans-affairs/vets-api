# frozen_string_literal: true

module ClaimsApi
  class UnsuccessfulReportMailer < ApplicationMailer
    RECIPIENTS = %w[
      michael.bastos@oddball.io
      ryan.link@oddball.io
      christopher.stone@libertyits.com
      valerie.hase@va.gov
      mark.greenburg@adhocteam.us
      premal.shah@va.gov
      lee.deboom@oddball.io
      dan.hinze@adhocteam.us
    ].freeze

    def build(consumer_totals, stuck_submissions, unsuccessful_submissions, date_from, date_to)
      @consumer_totals = consumer_totals
      @stuck_submissions = stuck_submissions
      @unsuccessful_submissions = unsuccessful_submissions
      @date_from = date_from
      @date_to = date_to

      path = ClaimsApi::Engine.root.join(
        'app',
        'views',
        'claims_api',
        'unsuccessful_report_mailer',
        'unsuccessful_report.html.erb'
      )
      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: RECIPIENTS,
        subject: 'Benefits Claims Unsuccessful Submission Report',
        body: body
      )
    end
  end
end
