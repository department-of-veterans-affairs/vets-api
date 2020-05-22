# frozen_string_literal: true

class YearToDateReportMailer < ApplicationMailer
  REPORT_TEXT = 'Year to date report'

  VA_STAKEHOLDERS = {
    to: %w[
      222A.VBAVACO@va.gov
      224B.VBAVACO@va.gov
      224C.VBAVACO@va.gov
      Anne.kainic@va.gov
      Brandon.Scott2@va.gov
      Brandye.Terrell@va.gov
      Carolyn.McCollam@va.gov
      Christina.DiTucci@va.gov
      Christopher.Marino2@va.gov
      Christopher.Sutherland@va.gov
      ian@adhocteam.us
      John.McNeal@va.gov
      Joseph.Welton@va.gov
      kathleen.dalfonso@va.gov
      kyle.pietrosanto@va.gov
      Lucas.Tickner@va.gov
      michele.mendola@va.gov
      peter.chou1@va.gov
      peter.nastasi@va.gov
      Ricardo.DaSilva@va.gov
      robert.shinners@va.gov
      shay.norton@va.gov
    ]
  }.freeze

  STAGING_RECIPIENTS = {
    to: %w[
      lihan@adhocteam.us
      Delli-Gatti_Michael@bah.com
      sonntag_adam@bah.com
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
