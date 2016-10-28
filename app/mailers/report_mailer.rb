# frozen_string_literal: true
class ReportMailer < ApplicationMailer
  # TODO: change this for production
  default to: 'lihan@adhocteam.us'

  def year_to_date_report_email(report_file)
    s3 = Aws::S3::Resource.new(
      region: ENV['REPORTS_AWS_S3_REGION'],
      access_key_id: ENV['REPORTS_AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['REPORTS_AWS_SECRET_ACCESS_KEY']
    )
    obj = s3.bucket(ENV['REPORTS_AWS_S3_BUCKET']).object("#{SecureRandom.uuid}.csv")
    obj.upload_file(report_file, content_type: 'text/csv')
    url = obj.presigned_url(:get, expires_in: 1.week)

    mail(
      subject: 'Year to date report',
      body: "Year to date report (link expires in one week)<br>#{url}"
    )
  end
end
