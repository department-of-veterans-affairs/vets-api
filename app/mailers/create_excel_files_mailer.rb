# frozen_string_literal: true

class CreateExcelFilesMailer < ApplicationMailer
  def build(filename)
    date = Time.zone.now.strftime('%m/%d/%Y')
    file_contents = File.read("tmp/#{filename}")
    headers['Content-Disposition'] = "attachment; filename=#{filename}"

    recipients = nil
    subject = nil

    if Settings.vsp_environment.eql?('production')
      recipients = Settings.edu.production_excel_contents.emails
      subject = "22-10282 Form CSV file for #{date}"
    else
      recipients = Settings.edu.staging_excel_contents.emails
      subject = "(Staging) 22-10282 CSV file for #{date}"
    end

    mail(
      to: recipients,
      subject: subject,
      content_type: 'text/csv',
      body: file_contents
    )
  end
end
