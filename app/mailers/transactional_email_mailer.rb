# frozen_string_literal: true

class TransactionalEmailMailer < ApplicationMailer
  def build(email, google_analytics_client_id, opt = {})
    @google_analytics_client_id = google_analytics_client_id
    @google_analytics_tracking_id = Settings.google_analytics.tracking_id

    mail(
      opt.merge(
        to: email,
        subject: self.class::SUBJECT,
        content_type: 'text/html',
        body: template
      )
    )
  end

  def first_initial_last_name(name)
    return '' if name.nil?

    "#{name.first[0, 1]} #{name.last}"
  end

  def first_and_last_name(name)
    return '' if name.nil?

    "#{name.first} #{name.last}"
  end

  def template(name = self.class::TEMPLATE)
    template_file = File.read("app/mailers/views/#{name}.html.erb")
    ERB.new(template_file).result(binding)
  end
end
