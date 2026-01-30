# frozen_string_literal: true

module VANotify
  module V2
    class QueueUserAccountJob
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

      def perform(user_account_id, template_id, attr_package_key, callback_options = {})
        attrs = fetch_attrs(attr_package_key, template_id)
        personalisation = attrs[:personalisation]
        api_key = attrs[:api_key]

        user_account = UserAccount.find(user_account_id)
        notify_client = VaNotify::Service.new(api_key, callback_options)

        begin
          notify_client.send_email(
            recipient_identifier: { id_value: user_account.icn, id_type: 'ICN' },
            template_id:,
            personalisation:
          )
          StatsD.increment('api.vanotify.v2.queue_user_account_job.success')
        rescue VANotify::Error => e
          StatsD.increment('api.vanotify.v2.queue_user_account_job.failure')
          handle_backend_exception(e)
        rescue => e
          StatsD.increment('api.vanotify.v2.queue_user_account_job.failure')
          raise e
        end
      end

      def self.enqueue(user_account_id, template_id, personalisation, api_key, callback_options = {})
        key = Sidekiq::AttrPackage.create(personalisation:, api_key:)
        perform_async(user_account_id, template_id, key, callback_options)
      end

      private

      def fetch_attrs(attr_package_key, template_id = nil)
        begin
          attrs = Sidekiq::AttrPackage.find(attr_package_key)
        rescue Sidekiq::AttrPackageError => e
          Rails.logger.error('VANotify::V2::QueueUserAccountJob AttrPackage error', {
                               error: e.message,
                               template_id:
                             })
          raise ArgumentError, e.message
        end

        if attrs
          attrs
        else
          Rails.logger.error('VANotify::V2::QueueUserAccountJob failed: Missing personalisation data in Redis', {
                               template_id:,
                               attr_package_key_present: attr_package_key.present?
                             })
          raise ArgumentError, 'Missing personalisation data in Redis'
        end
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
