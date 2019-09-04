# frozen_string_literal: true

class SpoolSubmissionsReportMailer < ApplicationMailer
  REPORT_TEXT = 'Spool submissions report'
  RECIPIENTS = %w[
    lihan@adhocteam.us
    dana.kuykendall@va.gov
    Jennifer.Waltz2@va.gov
    shay.norton@va.gov
    Darla.VanNieukerk@va.gov
    Ricardo.DaSilva@va.gov
  ].freeze

  # Will add in Prod STEM recipients once 18815 approved in staging
  STEM_RECIPIENTS = %w[].freeze

  STAGING_RECIPIENTS = %w[
    lihan@adhocteam.us
    Turner_Desiree@bah.com
    Delli-Gatti_Michael@bah.com
  ].freeze

  STAGING_STEM_RECIPIENTS = %w[
    kyle.pietrosanto@va.gov
    robert.shinners@va.gov
    shay.norton-leonard@va.gov
    hughes_dustin@bah.com
    sonntag_adam@bah.com
  ].freeze

  def add_stem_recipients
    return STAGING_STEM_RECIPIENTS.dup if FeatureFlipper.staging_email?
    STEM_RECIPIENTS.dup
  end

  def build(report_file, stem_exists)
    url = Reports::Uploader.get_s3_link(report_file)
    opt = {}

    opt[:to] =
      if FeatureFlipper.staging_email?
        STAGING_RECIPIENTS.dup
      else
        RECIPIENTS.dup
      end

    opt[:to] << add_stem_recipients if stem_exists

    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: "#{REPORT_TEXT} (link expires in one week)<br>#{url}"
      )
    )
  end
end
