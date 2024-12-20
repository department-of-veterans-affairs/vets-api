# frozen_string_literal: true
class CreateExcelFilesMailer < ApplicationMailer
  def build(filename)
    date = Time.zone.now.strftime('%m/%d/%Y')
    file_contents = File.read("tmp/#{filename}")
    headers['Content-Disposition'] = "attachment; filename=#{filename}"

    recipients = Settings.vsp_environment.eql?('production') ? Settings.edu.production_excel_contents.emails : Settings.edu.staging_excel_contents.emails
    subject = Settings.vsp_environment.eql?('production') ? "22-10282 Form CSV file for #{date}" : "Staging 22-10282 Form CSV file for #{date}"
    
    mail(
      to: recipients,
      subject: subject,
      content_type: 'text/csv',
      body: file_contents
    )
  end
end