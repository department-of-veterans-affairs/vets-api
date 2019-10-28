# frozen_string_literal: true

class SpoolSubmissionsReportMailer < ApplicationMailer
  REPORT_TEXT = 'Spool submissions report'
  RECIPIENTS = %w[
    dana.kuykendall@va.gov
    Darla.VanNieukerk@va.gov
    Jennifer.Waltz2@va.gov
    lihan@adhocteam.us
    Ricardo.DaSilva@va.gov
    shay.norton@va.gov
  ].freeze

  STEM_RECIPIENTS = %w[
    kyle.pietrosanto@va.gov
    robert.shinners@va.gov
  ].freeze

  STAGING_RECIPIENTS = %w[
    lihan@adhocteam.us
    shay.norton-leonard@va.gov
  ].freeze

  STAGING_STEM_RECIPIENTS = %w[
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
