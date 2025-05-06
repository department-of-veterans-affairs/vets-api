# frozen_string_literal: true

require 'sentry_logging'

class VANotifyDdEmailJob
  include Sidekiq::Job
  extend SentryLogging
  # retry for  2d 1h 47m 12s
  # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
  sidekiq_options retry: 16

  STATSD_ERROR_NAME = 'worker.direct_deposit_confirmation_email.error'
  STATSD_SUCCESS_NAME = 'worker.direct_deposit_confirmation_email.success'

  def self.send_to_emails(user_emails, dd_type = nil)
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

  def perform(email, dd_type = nil)
    notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
    template_type = template_type(dd_type)
    template_id = Settings.vanotify.services.va_gov.template_id.public_send(template_type)

    notify_client.send_email(
      email_address: email,
      template_id:
    )
    StatsD.increment(STATSD_SUCCESS_NAME)
  rescue => e
    handle_errors(e)
  end

  def template_type(dd_type)
    return 'direct_deposit_comp_pen' if use_comp_pen_email_template?(dd_type)

    'direct_deposit'
  end

  def handle_errors(ex)
    VANotifyDdEmailJob.log_exception_to_sentry(ex)
    StatsD.increment(STATSD_ERROR_NAME)

    raise ex if ex.status_code.between?(500, 599)
  end

  def use_direct_deposit_email_template?
    Flipper.enabled?(:only_use_direct_deposit_email_template)
  end

  def use_comp_pen_email_template?(dd_type)
    %i[comp_pen comp_and_pen].include?(dd_type&.to_sym) && !use_direct_deposit_email_template?
  end
end
