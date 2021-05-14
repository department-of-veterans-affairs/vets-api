# frozen_string_literal: true

require 'reports/uploader'

class Ch31SubmissionsReportMailer < ApplicationMailer
  REPORT_TEXT = 'Chapter 31 Submissions Report'

  VRE_RECIPIENTS = %w[
    VRE-CMS.VBAVACO@va.gov
    Jason.Wolf@va.gov
  ].freeze

  STAGING_RECIPIENTS = %w[
    kcrawford@governmentcio.com
  ].freeze

  def build(submitted_claims)
    opt = {}

    opt[:to] =
      if FeatureFlipper.staging_email?
        STAGING_RECIPIENTS
      else
        VRE_RECIPIENTS
      end

    @submitted_claims = submitted_claims
    @total = submitted_claims.size
    template = File.read('app/mailers/views/ch31_submissions_report.html.erb')

    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: ERB.new(template).result(binding)
      )
    )
  end
end
