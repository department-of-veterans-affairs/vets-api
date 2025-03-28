# frozen_string_literal: true

class CreateExcelFilesMailer < ApplicationMailer
  def build(filename)
    date = Time.zone.now.strftime('%m/%d/%Y')

    recipients = nil
    subject = nil

    if Settings.vsp_environment.eql?('production')
      recipients = Settings.edu.production_excel_contents.emails
      subject = "22-10282 Form CSV file for #{date}"
    else
      recipients = Settings.edu.staging_excel_contents.emails
      subject = "(Staging) 22-10282 CSV file for #{date}"
    end

    attachments[filename] = File.read("tmp/#{filename}")

    mail(
      to: recipients,
      subject:
    ) do |format|
      format.text { render plain: "CSV file for #{date} is attached." }
      format.html { render html: "CSV file for #{date} is attached." }
    end
  end
end
