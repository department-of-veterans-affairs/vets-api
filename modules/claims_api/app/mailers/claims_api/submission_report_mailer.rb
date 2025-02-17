# frozen_string_literal: true

module ClaimsApi
  class SubmissionReportMailer < ApplicationMailer
    RECIPIENTS = %w[
      drew.fisher@adhocteam.us
      emily.goodrich@oddball.io
      jennica.stiehl@oddball.io
      kayla.watanabe@adhocteam.us
      matthew.christianson@adhocteam.us
      rockwell.rice@oddball.io
      tyler.coleman@oddball.io
      Janet.Coutinho@va.gov
      Michael.Harlow@va.gov
    ].freeze

    def build(date_from, date_to, data)
      @date_from = date_from.in_time_zone('Eastern Time (US & Canada)').strftime('%a %D %I:%M %p')
      @date_to = date_to.in_time_zone('Eastern Time (US & Canada)').strftime('%a %D %I:%M %p')
      @data = { month: {} }

      @consumer_claims_totals = data[:consumer_claims_totals]
      @poa_totals = data[:poa_totals]
      @itf_totals = data[:itf_totals]
      @ews_totals = data[:ews_totals]

      @data.deep_symbolize_keys!

      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: RECIPIENTS,
        subject: 'Benefits Claims Monthly Submission Report', # rubocop:disable Rails/I18nLocaleTexts
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
        'submission_report_mailer',
        'submission_report.html.erb'
      )
    end
  end
end
