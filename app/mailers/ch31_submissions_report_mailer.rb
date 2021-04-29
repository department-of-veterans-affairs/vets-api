# frozen_string_literal: true

require 'reports/uploader'

class Ch31SubmissionsReportMailer < ApplicationMailer
  REPORT_TEXT = 'Chapter 31 Submissions Report'

  VRE_RECIPIENTS = %w[
    Jason.Wolf@va.gov
  ].freeze

  STAGING_RECIPIENTS = %w[
    kcrawford@governmentcio.com
  ].freeze

  def build(report_file)
    url = Reports::Uploader.get_s3_link(report_file)
    opt = {}

    opt[:to] =
      if FeatureFlipper.staging_email?
        STAGING_RECIPIENTS
      else
        VRE_RECIPIENTS
      end

    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: "#{REPORT_TEXT} (link expires in one week)<br>#{url}"
      )
    )
  end
end
