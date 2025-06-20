# frozen_string_literal: true

module Eps
  class AppointmentEmailWorker
    include Sidekiq::Job
    include SentryLogging
    sidekiq_options retry: 13
    STATSD_KEY = 'api.vaos.appointment_status_notification'

    def perform(user_uuid, appointment_id_last4, error = nil)
      appointment_data = fetch_appointment_data(user_uuid, appointment_id_last4)
      return unless appointment_data

      send_notification_email(appointment_data:, user_uuid:, appointment_id_last4:, error:)
    rescue => e
      handle_exception(error: e, user_uuid:, appointment_id_last4:)
    end

    sidekiq_retries_exhausted do |msg, ex|
      error_class = msg['error_class']
      error_message = msg['error_message']
      user_uuid = msg['args'][0]
      appointment_id_last4 = msg['args'][1]

      message = "Eps::AppointmentEmailJob retries exhausted: #{error_class} - #{error_message}"
      log_failure(error: ex, message:, user_uuid:, appointment_id_last4:, permanent: true)
    end

    def self.log_failure(error:, message:, user_uuid:, appointment_id_last4:, permanent: false)
      Rails.logger.error(message, { user_uuid:, appointment_id_last4: })
      SentryLogging.log_exception_to_sentry(
        error,
        { user_uuid:, appointment_id_last4: },
        { error: :eps_appointment_email_job, team: 'vaos' }
      )

      if permanent
        StatsD.increment("#{STATSD_KEY}.failure",
                         tags: ["user_uuid:#{user_uuid}", "appointment_id_last4:#{appointment_id_last4}"])
      else
        raise error
      end
    end

    private

    def send_notification_email(appointment_data:, user_uuid:, appointment_id_last4:, error:)
      notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)

      notify_client.send_email(
        email_address: appointment_data[:email],
        template_id: Settings.vanotify.services.va_gov.template_id.va_appointment_failure,
        personalisation: { 'error' => error }
      )
    end

    def fetch_appointment_data(user_uuid, appointment_id_last4)
      redis_client = Eps::RedisClient.new
      appointment_data = redis_client.fetch_appointment_data(uuid: user_uuid, appointment_id: appointment_id_last4)

      raise ArgumentError, 'missing appointment id' if appointment_data.nil?
      raise ArgumentError, 'missing email' if appointment_data[:email].blank?

      appointment_data
    rescue ArgumentError => e
      message = "Eps::AppointmentEmailJob #{e.message}: User UUID: #{user_uuid} - Appointment ID: #{appointment_id_last4}"
      self.class.log_failure(error: e, message:, user_uuid:, appointment_id_last4:, permanent: true)
      nil
    end

    def handle_exception(error:, user_uuid:, appointment_id_last4:)
      if error.respond_to?(:status_code) && error.status_code >= 400 && error.status_code < 500
        message = "Eps::AppointmentEmailJob upstream error - will not retry: #{error.status_code} - #{error.message}"
        self.class.log_failure(error:, message:, user_uuid:, appointment_id_last4:, permanent: true)
      elsif error.respond_to?(:status_code)
        message = "Eps::AppointmentEmailJob upstream error - will retry: #{error.status_code} - #{error.message}"
        self.class.log_failure(error:, message:, user_uuid:, appointment_id_last4:, permanent: false)
      else
        message = "Eps::AppointmentEmailJob unexpected error: #{error.class.name} - #{error.message}"
        self.class.log_failure(error:, message:, user_uuid:, appointment_id_last4:, permanent: true)
      end
    end
  end
end
