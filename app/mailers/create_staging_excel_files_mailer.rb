# frozen_string_literal: true

class CreateStagingExcelFilesMailer < ApplicationMailer
  def build(filename)
    date = Time.zone.now.strftime('%m/%d/%Y')
    file_contents = File.read("tmp/#{filename}")

    headers['Content-Disposition'] = "attachment; filename=#{filename}"

    mail(
      to: Settings.edu.staging_excel_contents.emails,
      subject: "Staging CSV file for #{date}",
      content_type: 'text/csv',
      body: file_contents
    )
  end
end
