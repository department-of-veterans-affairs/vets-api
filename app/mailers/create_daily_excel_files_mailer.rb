# frozen_string_literal: true

class CreateDailyExcelFilesMailer < ApplicationMailer
  def build
    date = Time.zone.now.strftime('%m%d%Y')
    opt = {}
    opt[:to] =
      if FeatureFlipper.staging_email?
        Settings.edu.excel_error.staging_emails.dup
      else
        Settings.edu.excel_error.emails.dup
      end

    mail(
      opt.merge(
        subject: "Error Generating Excel File on #{date}",
        body: "There was an error generating the Excel file on #{date}"
      )
    )
  end
end
