# frozen_string_literal: true

class TransactionalEmailMailer < ApplicationMailer
  def build(email, google_analytics_client_id, opt = {})
    @google_analytics_client_id = google_analytics_client_id
    @google_analytics_tracking_id = Settings.google_analytics.tracking_id

    template = File.read("app/mailers/views/#{self.class::TEMPLATE}.html.erb")

    mail(
      opt.merge(
        to: email,
        subject: self.class::SUBJECT,
        content_type: 'text/html',
        body: ERB.new(template).result(binding)
      )
    )
  end

  def first_initial_last_name(name)
    return '' if name.nil?

    "#{name.first[0, 1]} #{name.last}"
  end
end
