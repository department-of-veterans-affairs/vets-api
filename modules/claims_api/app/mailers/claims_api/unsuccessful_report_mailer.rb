# frozen_string_literal: true

module ClaimsApi
  class UnsuccessfulReportMailer < ApplicationMailer
    RECIPIENTS = %w[
      kayla.watanabe@adhocteam.us
      jennica.stiehl@oddball.io
      jeff.wallace@oddball.io
      zachary.goldfine@va.gov
      david.mazik@va.gov
      premal.shah@va.gov
      emily.goodrich@oddball.io
      christopher.stone@libertyits.com
      austin.covrig@oddball.io
      kelly.lein@adhocteam.us
    ].freeze

    def build(date_from, date_to, data)
      @date_from = date_from.in_time_zone('Eastern Time (US & Canada)').strftime('%a %D %I:%M %p')
      @date_to = date_to.in_time_zone('Eastern Time (US & Canada)').strftime('%a %D %I:%M %p')
      @consumer_claims_totals = data[:consumer_claims_totals]
      @unsuccessful_claims_submissions = data[:unsuccessful_claims_submissions]
      @poa_totals = data[:poa_totals]
      @unsuccessful_poa_submissions = data[:unsuccessful_poa_submissions]
      @itf_totals = data[:itf_totals]

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
