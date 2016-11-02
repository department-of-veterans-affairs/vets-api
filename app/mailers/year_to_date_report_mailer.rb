# frozen_string_literal: true
class YearToDateReportMailer < ApplicationMailer
  REPORT_TEXT = 'Year to date report'

  VA_STAKEHOLDERS = {
    to: %w(
      Christopher.Marino2@va.gov
      224A.VBACO@va.gov
      rodney.alexander@va.gov
      URSULA.BRITT@va.gov
      Carolyn.McCollam@va.gov
      shay.norton@va.gov
      Christina.DiTucci@va.gov
    ),
    cc: %w(
      robert.orifici@va.gov
      Erin.Haskins@va.gov
      Shante.Kinzie@va.gov
      Brandye.Terrell@va.gov
      michele.mendola@va.gov
      Schnell.Carraway@va.gov
      Danita.Johnson@va.gov
      jude.lopez1@va.gov
      Steven.Wayland@va.gov
    )
  }.freeze

  def build(report_file)
    s3_resource = new_s3_resource
    obj = s3_resource.bucket(s3_bucket).object("#{SecureRandom.uuid}.csv")
    obj.upload_file(report_file, content_type: 'text/csv')
    url = obj.presigned_url(:get, expires_in: 1.week)

    opt = {}
    if FeatureFlipper.staging_email?
      opt[:to] = 'lihan@adhocteam.us'
    else
      opt = VA_STAKEHOLDERS.clone
    end

    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: "#{REPORT_TEXT} (link expires in one week)<br>#{url}"
      )
    )
  end

  private

  def s3_bucket
    ENV['REPORTS_AWS_S3_BUCKET']
  end

  def new_s3_resource
    Aws::S3::Resource.new(
      region: ENV['REPORTS_AWS_S3_REGION'],
      access_key_id: ENV['REPORTS_AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['REPORTS_AWS_SECRET_ACCESS_KEY']
    )
  end
end
