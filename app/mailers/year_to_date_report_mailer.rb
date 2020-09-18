# frozen_string_literal: true

require 'reports/uploader'

class YearToDateReportMailer < ApplicationMailer
  REPORT_TEXT = 'Year to date report'

  VA_STAKEHOLDERS = {
    to: %w[
      222A.VBAVACO@va.gov
      224B.VBAVACO@va.gov
      224C.VBAVACO@va.gov
      Brandon.Scott2@va.gov
      Brian.Grubb@va.gov
      Christina.DiTucci@va.gov
      John.McNeal@va.gov
      Joseph.Preisser@va.gov
      Joseph.Welton@va.gov
      kathleen.dalfonso@va.gov
      kyle.pietrosanto@va.gov
      Lucas.Tickner@va.gov
      michele.mendola@va.gov
      Ricardo.DaSilva@va.gov
      shay.norton@va.gov
      tammy.hurley1@va.gov
    ]
  }.freeze

  STAGING_RECIPIENTS = {
    to: %w[
      Brian.Grubb@va.gov
      Delli-Gatti_Michael@bah.com
      Joseph.Preisser@va.gov
      Joseph.Welton@va.gov
      kyle.pietrosanto@va.gov
      Lucas.Tickner@va.gov
      lihan@adhocteam.us
      matthew.ziolkowski@va.gov
      Michael.Johnson19@va.gov
      neel_darrell@bah.com
      Ricardo.DaSilva@va.gov
      shawkey_daniel@bah.com
      sonntag_adam@bah.com
      tammy.hurley1@va.gov
      turner_desiree@bah.com
    ]
  }.freeze

  def build(report_file)
    url = Reports::Uploader.get_s3_link(report_file)

    opt = if FeatureFlipper.staging_email?
            STAGING_RECIPIENTS.clone
          else
            VA_STAKEHOLDERS.clone
          end
    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: "#{REPORT_TEXT} (link expires in one week)<br>#{url}"
      )
    )
  end
end
