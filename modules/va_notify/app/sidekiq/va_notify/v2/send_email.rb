# frozen_string_literal: true

module VANotify
  module V2
    class SendEmail
      include Sidekiq::Job
      include Vets::SharedLogging
      sidekiq_options retry: 14

      sidekiq_retries_exhausted do |msg, _ex|
        job_id = msg['jid']
        job_class = msg['class']
        error_class = msg['error_class']
        error_message = msg['error_message']

        message = "#{job_class} retries exhausted"
        Rails.logger.error(message, { job_id:, error_class:, error_message: })
        StatsD.increment("sidekiq.jobs.#{job_class.underscore}.retries_exhausted")
      end

      def perform(email, template_id, attr_package_key, api_key, callback_options = {})
        personalisation = fetch_and_cleanup_personalisation(attr_package_key)
        return unless personalisation

        VaNotify::Service.new(api_key, callback_options).send_email(
          email_address: email,
          template_id:,
          personalisation:
        )

        StatsD.increment('api.vanotify.email_job.success')
        response
        rescue VANotify::Error => e
          handle_backend_exception(e)
      end

      def self.enqueue(email, template_id, personalisation, api_key, callback_options = {})
        key = Sidekiq::AttrPackage.create(attrs: { personalisation: })
        perform_async(email, template_id, key, api_key, callback_options)
      end

      private

      def fetch_and_cleanup_personalisation(attr_package_key)
        attrs = Sidekiq::AttrPackage.find(attr_package_key)
        Sidekiq::AttrPackage.delete(attr_package_key) if attrs
        attrs&.dig(:personalisation)
      end

      def handle_backend_exception(e)
        if e.status_code == 400
          log_exception_to_rails(e)
        else
          raise e
        end
      end
    end
  end
end
