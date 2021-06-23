# frozen_string_literal: true

class VANotifyEmailJob
  include Sidekiq::Worker
  sidekiq_options expires_in: 1.day

  def perform(email, template_id, personalisation = nil)
    notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)

    notify_client.send_email(
      {
        email_address: email,
        template_id: template_id,
        personalisation: personalisation
      }.compact
    )
  end
end
