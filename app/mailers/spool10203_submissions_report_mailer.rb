# frozen_string_literal: true

require 'reports/uploader'

class Spool10203SubmissionsReportMailer < ApplicationMailer
  REPORT_TEXT = '10203 spool submissions report'

  def build(report_file)
    url = Reports::Uploader.get_s3_link(report_file)
    opt = {}

    opt[:to] =
      if FeatureFlipper.staging_email?
        Settings.reports.spool10203_submission.staging_emails.dup
      else
        Settings.reports.spool10203_submission.emails.dup
      end

    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: "#{REPORT_TEXT} (link expires in one week)<br>#{url}"
      )
    )
  end
end
