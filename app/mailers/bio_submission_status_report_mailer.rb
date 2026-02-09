# frozen_string_literal: true

class BioSubmissionStatusReportMailer < ApplicationMailer
  REPORT_TEXT = 'BIO Submission Status Report'

  def build(s3_links)
    opt = {}

    raw_emails =
      if FeatureFlipper.staging_email?
        Settings.reports&.bio_submission_status&.staging_emails
      else
        Settings.reports&.bio_submission_status&.emails
      end

    opt[:to] = Array(raw_emails).select { |email| email.is_a?(String) && !email.strip.empty? }

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
