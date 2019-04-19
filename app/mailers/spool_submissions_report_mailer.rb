# frozen_string_literal: true

class SpoolSubmissionsReportMailer < ApplicationMailer
  REPORT_TEXT = 'Spool submissions report'
  RECIPIENTS = %w[
    lihan@adhocteam.us
    dana.kuykendall@va.gov
    Jennifer.Waltz2@va.gov
    shay.norton@va.gov
    Darla.VanNieukerk@va.gov
  ].freeze
  STAGING_RECIPIENTS = %w[
    lihan@adhocteam.us
    Turner_Desiree@bah.com
    Delli-Gatti_Michael@bah.com
  ].freeze

  def build(report_file)
    url = Reports::Uploader.get_s3_link(report_file)

    opt = {}

    opt[:to] =
      if FeatureFlipper.staging_email?
        STAGING_RECIPIENTS.clone
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
