# frozen_string_literal: true

class RrdAlertMailer < ApplicationMailer
  def build(submission, subject, message, error = nil, to = Settings.rrd.alerts.recipients)
    @id = submission.id
    @message = message
    @error = error
    template = File.read('app/mailers/views/rrd_alert_mailer.html.erb')
    environment = "[#{Settings.vsp_environment}] " unless Settings.vsp_environment == 'production'

    mail(
      to:,
      subject:,
      body: ERB.new(template).result(binding)
    )
  end
end
