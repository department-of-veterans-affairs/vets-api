# frozen_string_literal: true

require 'reports/uploader'

class YearToDateReportMailer < ApplicationMailer
  REPORT_TEXT = 'Year to date report'
  def build(report_file)
    url = Reports::Uploader.get_s3_link(report_file)
    opt = {}
    opt[:to] = if FeatureFlipper.staging_email?
                 Settings.reports.year_to_date_report.staging_emails.dup
               else
                 Settings.reports.year_to_date_report.emails.dup
               end
    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: "#{REPORT_TEXT} (link expires in one week)<br>#{url}"
      )
    )
  end
end
