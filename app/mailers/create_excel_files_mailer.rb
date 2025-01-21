# frozen_string_literal: true

class CreateExcelFilesMailer < ApplicationMailer
  def build(filename)
    date = Time.zone.now.strftime('%m/%d/%Y')

    # rubocop:disable Layout/LineLength
    recipients = Settings.vsp_environment.eql?('production') ? Settings.edu.production_excel_contents.emails : Settings.edu.staging_excel_contents.emails
    subject = Settings.vsp_environment.eql?('production') ? "22-10282 Form CSV file for #{date}" : "Staging CSV file for #{date}"
    # rubocop:enable Layout/LineLength

    attachments[filename] = File.read("tmp/#{filename}")

    mail(
      to: recipients,
      subject: subject
    ) do |format|
      format.text { render plain: "CSV file for #{date} is attached." }
      format.html { render html: "<p>CSV file for #{date} is attached.</p>" }
    end
  end
end
