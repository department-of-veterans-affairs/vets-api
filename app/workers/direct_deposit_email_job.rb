# frozen_string_literal: true

class DirectDepositEmailJob
  include Sidekiq::Worker
  extend SentryLogging
  sidekiq_options retry: 14

  def self.send_to_emails(user_emails, ga_client_id, dd_type)
    if user_emails.present?
      user_emails.each do |email|
        perform_async(email, ga_client_id, dd_type)
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

  def perform(email, ga_client_id, dd_type)
    DirectDepositMailer.build(email, ga_client_id, dd_type).deliver_now
  end
end
