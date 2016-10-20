class ReportMailer < ApplicationMailer
  # TODO change this for production
  default to: 'lihan@adhocteam.us'

  def year_to_date_report_email(report)
    # TODO add report as s3 upload
    # attachments['report.csv'] = report

    mail(
      subject: 'Year to date report',
      body: 'Year to date report'
    )
  end
end
