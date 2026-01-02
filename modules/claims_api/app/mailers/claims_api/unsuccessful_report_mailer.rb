# frozen_string_literal: true

module ClaimsApi
  class UnsuccessfulReportMailer < ApplicationMailer
    RECIPIENTS = %w[
      david.mazik@va.gov
      drew.fisher@adhocteam.us
      eshvimmer@deloitte.com
      janet.coutinho@va.gov
      jgreene@technatomy.com
      mbavanaka@deloitte.com
      mchristianson@technatomy.com
      michael.clement@adhocteam.us
      michael.harlow@va.gov
      mughumman@deloitte.com
      mzanaty@technatomy.com
      robert.perea-martinez@adhocteam.us
      rrice@technatomy.com
      slamsal@deloitte.com
      stone_christopher@bah.com
      zachary.goldfine@va.gov
    ].freeze

    def build(date_from, date_to, data)
      @date_from = date_from.in_time_zone('Eastern Time (US & Canada)').strftime('%a %D %I:%M %p')
      @date_to = date_to.in_time_zone('Eastern Time (US & Canada)').strftime('%a %D %I:%M %p')
      @consumer_claims_totals = data[:consumer_claims_totals]
      @unsuccessful_claims_submissions = data[:unsuccessful_claims_submissions]
      @unsuccessful_va_gov_claims_submissions = data[:unsuccessful_va_gov_claims_submissions]
      @poa_totals = data[:poa_totals]
      @unsuccessful_poa_submissions = data[:unsuccessful_poa_submissions]
      @itf_totals = data[:itf_totals]
      @ews_totals = data[:ews_totals]
      @unsuccessful_evidence_waiver_submissions = data[:unsuccessful_evidence_waiver_submissions]

      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: RECIPIENTS,
        subject: 'Benefits Claims Daily Submission Report',
        content_type: 'text/html',
        body:
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
