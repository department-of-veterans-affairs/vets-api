# frozen_string_literal: true

class TransactionalEmailMailer < ApplicationMailer
  def build(email, google_analytics_client_id, opt = {})
    @google_analytics_client_id = google_analytics_client_id
    @google_analytics_tracking_id = Settings.google_analytics_tracking_id

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

  # N/A is used for "the user wasn't shown this option", which is distinct from Y/N.
  def yesno(bool)
    return 'N/A' if bool.nil?

    bool ? 'YES' : 'NO'
  end

  def value_or_na(value)
    value.nil? ? 'N/A' : value
  end

  def full_name(name)
    return '' if name.nil?

    [name.first, name.middle, name.last, name&.suffix].compact.join(' ')
  end
end
