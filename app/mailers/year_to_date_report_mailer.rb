# frozen_string_literal: true

class YearToDateReportMailer < ApplicationMailer
  REPORT_TEXT = 'Year to date report'

  VA_STAKEHOLDERS = {
    to: %w[
      Christopher.Marino2@va.gov
      224B.VBAVACO@va.gov
      rodney.alexander@va.gov
      Carolyn.McCollam@va.gov
      shay.norton@va.gov
      Christina.DiTucci@va.gov
      Brandye.Terrell@va.gov
      michele.mendola@va.gov
      Christopher.Sutherland@va.gov
      John.McNeal@va.gov
      Anne.kainic@va.gov
      ian@adhocteam.us
      dan.hoicowitz.va@gmail.com
      Darla.VanNieukerk@va.gov
      Brandon.Scott2@va.gov
      224C.VBAVACO@va.gov
      peter.chou1@va.gov
      Joseph.Welton@va.gov
      222A.VBAVACO@va.gov
    ]
  }.freeze

  STAGING_RECIPIENTS = {
    to: %w[
      lihan@adhocteam.us
      Turner_Desiree@bah.com
      Delli-Gatti_Michael@bah.com
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
