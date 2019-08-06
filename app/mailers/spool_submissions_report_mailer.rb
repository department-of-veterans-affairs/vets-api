# frozen_string_literal: true

class SpoolSubmissionsReportMailer < ApplicationMailer
  REPORT_TEXT = 'Spool submissions report'
  RECIPIENTS = %w[
    lihan@adhocteam.us
    dana.kuykendall@va.gov
    Jennifer.Waltz2@va.gov
    shay.norton@va.gov
    Darla.VanNieukerk@va.gov
    Ricardo.DaSilva@va.gov  ]

  STEM_RECIPIENTS = %w[]

  STAGING_RECIPIENTS = %w[
    lihan@adhocteam.us
    Turner_Desiree@bah.com
    Delli-Gatti_Michael@bah.com
  ]

  STAGING_STEM_RECIPIENTS = %w[
    shay.norton-leonard@va.gov
    hughes_dustin@bah.com
  ]

  def build(report_file, stem_exists)
    url = Reports::Uploader.get_s3_link(report_file)

    opt = {}

    opt[:to] =
      if FeatureFlipper.staging_email?
        STAGING_RECIPIENTS.clone
      else
        RECIPIENTS.clone
      end

     if stem_exists
       if FeatureFlipper.staging_email?
         opt[:to] << STAGING_STEM_RECIPIENTS.clone
       else
         opt[:to] << STEM_RECIPIENTS.clone
       end
     end

    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: "#{REPORT_TEXT} (link expires in one week)<br>#{url}"
      )
    )
  end
end
