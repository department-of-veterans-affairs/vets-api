# frozen_string_literal: true

require 'reports/uploader'

class SpoolSubmissionsReportMailer < ApplicationMailer
  REPORT_TEXT = 'Spool submissions report'
  RECIPIENTS = %w[
    Brian.Grubb@va.gov
    dana.kuykendall@va.gov
    Jennifer.Waltz2@va.gov
    Joseph.Preisser@va.gov
    Joseph.Welton@va.gov
    kathleen.dalfonso@va.gov
    lihan@adhocteam.us
    Lucas.Tickner@va.gov
    Ricardo.DaSilva@va.gov
    shay.norton@va.gov
    tammy.hurley1@va.gov
  ].freeze

  STEM_RECIPIENTS = %w[
    kyle.pietrosanto@va.gov
    robert.shinners@va.gov
  ].freeze

  STAGING_RECIPIENTS = %w[
    Brian.Grubb@va.gov
    Darrell.Neel@va.gov
    Delli-Gatti_Michael@bah.com
    Joseph.Preisser@va.gov
    Joseph.Welton@va.gov
    lihan@adhocteam.us
    Neel_Darrell@bah.com
    shawkey_daniel@bah.com
    sonntag_adam@bah.com
    tammy.hurley1@va.gov
    Turner_Desiree@bah.com
  ].freeze

  STAGING_STEM_RECIPIENTS = %w[
    Delli-Gatti_Michael@bah.com
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
