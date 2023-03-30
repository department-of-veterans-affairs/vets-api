# frozen_string_literal: true

class VANotifyDdEmailJob
  include Sidekiq::Worker
  extend SentryLogging
  sidekiq_options retry: 14

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
    template_type = "direct_deposit_#{dd_type.to_sym == :ch33 ? 'edu' : 'comp_pen'}"
    template_id = Settings.vanotify.services.va_gov.template_id.public_send(template_type)

    notify_client.send_email(
      email_address: email,
      template_id:
    )
  end
end
