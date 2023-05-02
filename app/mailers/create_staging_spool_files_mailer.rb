# frozen_string_literal: true

require 'reports/uploader'

class CreateStagingSpoolFilesMailer < ApplicationMailer
  def build(filename)
    date = Time.zone.now.strftime('%m%d%Y')
    opt = {}
    opt[:to] = Settings.edu.staging_spool_contents.emails.dup
    attachments[filename.to_s] = File.read("#{Rails.root.join('tmp')}/#{filename}")

    mail(
      opt.merge(
        subject: "Staging Spool file on #{date}",
        body: "The staging spool file for #{date}"
      )
    )
  end
end
