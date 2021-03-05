# frozen_string_literal: true

class VANotifyDdEmailJob
  include Sidekiq::Worker
  extend SentryLogging
  sidekiq_options expires_in: 1.day

  def self.send_to_emails(user_emails, dd_type)
    if user_emails.present?
      user_emails.each do |email|
        perform_async(email, dd_type)
      end
    else
      log_message_to_sentry(
        'Direct Deposit info update: no email address present for confirmation email',
        :info,
        {},
        feature: 'direct_deposit'
      )
    end
  end

  def perform(email, dd_type)
    notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
    template_id = Settings.vanotify.template_id.public_send("direct_deposit_#{dd_type == :ch33 ? 'edu' : 'comp_pen'}")

    notify_client.send_email(
      email_address: email,
      template_id: template_id
    )
  end
end
