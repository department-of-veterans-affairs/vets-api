# frozen_string_literal: true

class TransactionalEmailMailer < ApplicationMailer
  def build(email, google_analytics_client_id)
    @google_analytics_client_id = google_analytics_client_id
    @google_analytics_tracking_id = Settings.google_analytics_tracking_id

    template = File.read("app/mailers/views/#{self.class::TEMPLATE}.html.erb")

    mail(
      to: email,
      subject: self.class::SUBJECT,
      content_type: 'text/html',
      body: ERB.new(template).result(binding)
    )
  end
end
