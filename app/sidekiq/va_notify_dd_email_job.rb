# frozen_string_literal: true

class VANotifyDdEmailJob
  include Sidekiq::Job
  # retry for  2d 1h 47m 12s
  # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
  sidekiq_options retry: 16

  STATSD_ERROR_NAME = 'worker.direct_deposit_confirmation_email.error'
  STATSD_SUCCESS_NAME = 'worker.direct_deposit_confirmation_email.success'

  def self.send_to_emails(user_emails)
    if user_emails.present?
      user_emails.each do |email|
        perform_async(email)
      end
    else
      Rails.logger.info(
        event: 'direct_deposit_confirmation_skipped',
        reason: 'missing_email',
        context: {
          feature: 'direct_deposit',
          job: name
        },
        message: 'No email address present for Direct Deposit confirmation email'
      )
    end
  end

  def perform(email)
    notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
    template_id = Settings.vanotify.services.va_gov.template_id[:direct_deposit]

    notify_client.send_email(
      email_address: email,
      template_id:
    )
    StatsD.increment(STATSD_SUCCESS_NAME)
  rescue => e
    handle_errors(e)
  end

  def handle_errors(exception)
    StatsD.increment(STATSD_ERROR_NAME)

    Rails.logger.error(
      message: 'Direct Deposit confirmation email job failed',
      error: exception.message,
      backtrace: exception.backtrace.take(5),
      source: self.class.name
    )

    raise exception if exception.status_code.between?(500, 599)
  end
end
