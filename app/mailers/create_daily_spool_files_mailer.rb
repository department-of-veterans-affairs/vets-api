# frozen_string_literal: true

require 'reports/uploader'

class CreateDailySpoolFilesMailer < ApplicationMailer
  def build(region = nil)
    date = Time.zone.now.strftime('%m%d%Y')
    rpo_msg = if region.nil?
                'files'
              else
                "file for #{EducationForm::EducationFacility.rpo_name(region:)}"
              end
    opt = {}
    opt[:to] =
      if FeatureFlipper.staging_email?
        Settings.edu.spool_error.staging_emails.dup
      else
        Settings.edu.spool_error.emails.dup
      end

    mail(
      opt.merge(
        subject: "Error Generating Spool file on #{date}",
        body: "There was an error generating the spool #{rpo_msg} on #{date}"
      )
    )
  end
end
