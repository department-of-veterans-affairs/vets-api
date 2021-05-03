# frozen_string_literal: true

class FailedClaimsReportMailer < ApplicationMailer
  RECIPIENTS = %w[
    anna@adhocteam.us
  ].freeze

  def build(failed_uploads)
    opt = {}
    opt[:to] = RECIPIENTS.clone

    @failed_uploads = failed_uploads
    template = File.read('app/mailers/views/failed_claims_report.erb')

    mail(
      opt.merge(
        subject: 'EVSS claims failed to upload',
        body: ERB.new(template).result(binding)
      )
    )
  end
end
