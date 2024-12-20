# frozen_string_literal: true

class CreateExcelFilesMailer < ApplicationMailer
  def build(filename)
    date = Time.zone.now.strftime('%m/%d/%Y')
    file_contents = File.read("tmp/#{filename}")

    headers['Content-Disposition'] = "attachment; filename=#{filename}"

    if Settings.vsp_environment.eql?('production')
      mail(
        to: Settings.edu.production_excel_contents.emails,
        subject: "22-10282 Form CSV file for #{date}",
        content_type: 'text/csv',
        body: file_contents
      )
    else
      mail(
        to: Settings.edu.staging_excel_contents.emails,
        subject: "Staging 22-10282 Form CSV file for #{date}",
        content_type: 'text/csv',
        body: file_contents
      )
    end
  end
end
