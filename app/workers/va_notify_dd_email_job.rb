# frozen_string_literal: true

class VANotifyDdEmailJob
  include Sidekiq::Worker

  sidekiq_options expires_in: 1.day

  def perform(email, dd_type)
    notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
    template_id = Settings.vanotify.template_id.public_send("direct_deposit_#{dd_type == :ch33 ? 'edu' : 'comp_pen'}")

    notify_client.send_email(
      email_address: email,
      template_id: template_id
    )
  end
end
