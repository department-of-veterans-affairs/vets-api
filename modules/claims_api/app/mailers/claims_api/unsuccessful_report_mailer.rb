# frozen_string_literal: true

module ClaimsApi
  class UnsuccessfulReportMailer < ApplicationMailer
    RECIPIENTS = %w[
      zachary.goldfine@va.gov
      david.mazik@va.gov
      premal.shah@va.gov
      mark.greenburg@adhocteam.us
      emily.goodrich@oddball.io
      lee.deboom@oddball.io
      dan.hinze@adhocteam.us
      ryan.link@oddball.io
      christopher.stone@libertyits.com
      jeff.wallace@oddball.io
    ].freeze

    def build(date_from, date_to, data)
      @consumer_totals = data[:consumer_totals]
      @pending_submissions = data[:pending_submissions]
      @unsuccessful_submissions = data[:unsuccessful_submissions]
      @grouped_errors = data[:grouped_errors]
      @grouped_warnings = data[:grouped_warnings]
      @flash_statistics = data[:flash_statistics]
      @special_issues_statistics = data[:special_issues_statistics]
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
