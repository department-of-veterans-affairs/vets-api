# frozen_string_literal: true

module DebtManagementCenter
  class VANotifyEmailJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options retry: 14

    def perform(email, template_id, personalisation = nil)
      notify_client = VaNotify::Service.new(Settings.vanotify.services.dmc.api_key)

      notify_client.send_email(
        {
          email_address: email,
          template_id: template_id,
          personalisation: personalisation
        }.compact
      )
    rescue Common::Exceptions::BackendServiceException => e
      if e.status_code == 400
        log_exception_to_sentry(
          e,
          {
            args: { email: email, template_id: template_id, personalisation: personalisation }
          },
          { error: :dmc_va_notify_email_job }
        )
      else
        raise e
      end
    end
  end
end
