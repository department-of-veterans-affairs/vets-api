# frozen_string_literal: true

class SpoolSubmissionsReportMailer < ApplicationMailer
  REPORT_TEXT = 'Spool submissions report'
  RECIPIENTS = %w(
    lihan@adhocteam.us
    dana.kuykendall@va.gov
    Jennifer.Waltz2@va.gov
    shay.norton@va.gov
    DONALD.NOBLE2@va.gov
  ).freeze

  def build(report_file)
    url = Reports::Uploader.get_s3_link(report_file)

    opt = {}
    opt[:to] =
      if FeatureFlipper.staging_email?
        'lihan@adhocteam.us'
      else
        RECIPIENTS.clone
      end

    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: "#{REPORT_TEXT} (link expires in one week)<br>#{url}"
      )
    )
  end
end
