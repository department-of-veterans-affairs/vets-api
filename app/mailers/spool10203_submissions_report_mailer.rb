# frozen_string_literal: true

require 'reports/uploader'

class Spool10203SubmissionsReportMailer < ApplicationMailer
  REPORT_TEXT = '10203 spool submissions report'
  RECIPIENTS = %w[
    Brian.Grubb@va.gov
    Joseph.Preisser@va.gov
    Lucas.Tickner@va.gov
    tammy.hurley1@va.gov
    Ricardo.DaSilva@va.gov
    kyle.pietrosanto@va.gov
    Joshua.Lashbrook@va.gov
    shay.norton@va.gov
    dana.kuykendall@va.gov
    Jennifer.Waltz2@va.gov
    kathleen.dalfonso@va.gov
    lihan@adhocteam.us
  ].freeze

  STAGING_RECIPIENTS = %w[
    Brian.Grubb@va.gov
    Joseph.Preisser@va.gov
    Lucas.Tickner@va.gov
    tammy.hurley1@va.gov
    Ricardo.DaSilva@va.gov
    kyle.pietrosanto@va.gov
    lihan@adhocteam.us
    Delli-Gatti_Michael@bah.com
    Darrell.Neel@va.gov
    Neel_Darrell@bah.com
    shawkey_daniel@bah.com
    sonntag_adam@bah.com
    Turner_Desiree@bah.com
  ].freeze

  def build(report_file)
    url = Reports::Uploader.get_s3_link(report_file)
    opt = {}

    opt[:to] =
      if FeatureFlipper.staging_email?
        STAGING_RECIPIENTS.dup
      else
        RECIPIENTS.dup
      end

    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: "#{REPORT_TEXT} (link expires in one week)<br>#{url}"
      )
    )
  end
end
