# frozen_string_literal: true

require 'reports/uploader'

class CreateStagingSpoolFilesMailer < ApplicationMailer
  def build(contents)
    date = Time.zone.now.strftime('%m%d%Y')
    opt = {}
    opt[:to] = Settings.edu.staging_spool_contents.emails.dup
    note_str = '*** note: to see the contents in the correct format, copy into notepad ***'
    mail(
      opt.merge(
        subject: "Staging Spool file on #{date}",
        body: "The staging spool file for #{date} #{note_str}\n\n\n#{contents}"
      )
    )
  end
end
