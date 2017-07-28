# frozen_string_literal: true
class SpoolSubmissionsReportMailer < ApplicationMailer
  REPORT_TEXT = 'Spool submissions report'

  def build(report_file)
    url = Reports::Uploader.get_s3_link(report_file)

    opt = {
      to: 'lihan@adhocteam.us'
    }

    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: "#{REPORT_TEXT} (link expires in one week)<br>#{url}"
      )
    )
  end
end
