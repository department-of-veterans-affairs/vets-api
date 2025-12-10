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
        attrs = fetch_attrs(email, template_id, attr_package_key)
        personalisation = attrs[:personalisation]

        begin
          VaNotify::Service.new(api_key, callback_options).send_email(
            email_address: email,
            template_id:,
            personalisation:
          )
          Sidekiq::AttrPackage.delete(attr_package_key)
          StatsD.increment('api.vanotify.v2.send_email.success')
        rescue VANotify::Error => e
          StatsD.increment('api.vanotify.v2.send_email.failure')
          handle_backend_exception(e)
        rescue => e
          StatsD.increment('api.vanotify.v2.send_email.failure')
          raise e
        end
      end

      def self.enqueue(email, template_id, personalisation, api_key, callback_options = {})
        key = Sidekiq::AttrPackage.create(attrs: { personalisation: })
        perform_async(email, template_id, key, api_key, callback_options)
      end

      private

      # rubocop:disable Metrics/MethodLength
      def fetch_attrs(email, template_id, attr_package_key)
        begin
          attrs = Sidekiq::AttrPackage.find(attr_package_key)
        rescue Sidekiq::AttrPackageError => e
          Rails.logger.error('VANotify::V2::SendEmail AttrPackage error', {
                               error: e.message,
                               email:,
                               template_id:,
                               attr_package_key:
                             })
          raise ArgumentError, e.message
        end

        if attrs
          attrs
        else
          Rails.logger.error('VANotify::V2::SendEmail failed: Missing personalisation data in Redis', {
                               email:,
                               template_id:,
                               attr_package_key_present: attr_package_key.present?
                             })
          raise ArgumentError, 'Missing personalisation data in Redis'

          nil
        end
      end
      # rubocop:enable Metrics/MethodLength

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
