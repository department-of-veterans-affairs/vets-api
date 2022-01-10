# frozen_string_literal: true

module ClaimsApi
  class UnsuccessfulReportMailer < ApplicationMailer
    RECIPIENTS = %w[
      zachary.goldfine@va.gov
      david.mazik@va.gov
      premal.shah@va.gov
      kayla.watanabe@adhocteam.us
      emily.goodrich@oddball.io
      lee.deboom@oddball.io
      dan.hinze@adhocteam.us
      christopher.stone@libertyits.com
      jeff.wallace@oddball.io
    ].freeze

    def build(date_from, date_to, data)
      @date_from = date_from
      @date_to = date_to
      @consumer_claims_totals = data[:consumer_claims_totals]
      @pending_claims_submissions = data[:pending_claims_submissions]
      @unsuccessful_claims_submissions = data[:unsuccessful_claims_submissions]
      @grouped_claims_errors = data[:grouped_claims_errors]
      @grouped_claims_warnings = data[:grouped_claims_warnings]
      @flash_statistics = data[:flash_statistics]
      @special_issues_statistics = data[:special_issues_statistics]
      @poa_totals = poa_totals = data[:poa_totals]
      @unsuccessful_poa_submissions = data[:unsuccessful_poa_submissions]

      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: RECIPIENTS,
        subject: 'Benefits Claims Daily Submission Report',
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
