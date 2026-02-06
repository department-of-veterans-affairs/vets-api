# frozen_string_literal: true

require 'reports/uploader'

class BioSubmissionStatusReportMailer < ApplicationMailer
  REPORT_TEXT = 'BIO Submission Status Report'

  def build(s3_links)
    opt = {}

    opt[:to] =
      if FeatureFlipper.staging_email?
        Settings.reports.bio_submission_status.staging_emails.dup
      else
        Settings.reports.bio_submission_status.emails.dup
      end

    links_html = s3_links.map do |form_type, url|
      "#{form_type}: #{url}"
    end.join('<br>')

    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: "#{REPORT_TEXT} (links expire in one week)<br><br>#{links_html}"
      )
    )
  end
end
