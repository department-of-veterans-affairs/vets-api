# frozen_string_literal: true

module ClaimsApi
  class UnsuccessfulReportMailer < ApplicationMailer
    RECIPIENTS = %w[
      david.mazik@va.gov
      michael.bastos@oddball.io
      ryan.link@oddball.io
      christopher.stone@libertyits.com
      valerie.hase@va.gov
      mark.greenburg@adhocteam.us
      premal.shah@va.gov
      lee.deboom@oddball.io
      dan.hinze@adhocteam.us
      seth.johnson@gdit.com
      kayur.shah@gdit.com
      tim.barto@gdit.com
      zachary.goldfine@va.gov
    ].freeze

    def build(date_from, date_to, data)
      @consumer_totals = data[:consumer_totals]
      @pending_submissions = data[:pending_submissions]
      @unsuccessful_submissions = data[:unsuccessful_submissions]
      @flash_statistics = data[:flash_statistics]
      @date_from = date_from
      @date_to = date_to

      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: RECIPIENTS,
        subject: 'Benefits Claims Unsuccessful Submission Report',
        content_type: 'text/html',
        body: body
      )
    end

    private

    def path
      ClaimsApi::Engine.root.join(
        'app',
        'views',
        'claims_api',
        'unsuccessful_report_mailer',
        'unsuccessful_report.html.erb'
      )
    end
  end
end
