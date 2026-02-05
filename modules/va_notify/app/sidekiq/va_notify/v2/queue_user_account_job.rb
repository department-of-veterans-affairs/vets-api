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

      def perform(user_account_id, template_id, attr_package_key, api_key_path, callback_options = {})
        attrs = fetch_attrs(attr_package_key, template_id)
        personalisation = attrs[:personalisation]
        api_key = resolve_api_key(api_key_path)

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

      def self.enqueue(user_account_id, template_id, personalisation, api_key_path, callback_options = {})
        key = Sidekiq::AttrPackage.create(personalisation:)
        perform_async(user_account_id, template_id, key, api_key_path, callback_options)
      rescue Redis::BaseError, Sidekiq::AttrPackageError => e
        Rails.logger.error('VANotify::V2::QueueUserAccountJob enqueue failed', {
                             error_class: e.class.name,
                             template_id:
                           })
        StatsD.increment('api.vanotify.v2.queue_user_account_job.enqueue_failure')
        raise
      end

      private

      def fetch_attrs(attr_package_key, template_id = nil)
        attrs = Sidekiq::AttrPackage.find(attr_package_key)
        return attrs if attrs

        Rails.logger.error('VANotify::V2::QueueUserAccountJob failed: Missing personalisation data in Redis', {
                             template_id:,
                             attr_package_key_present: attr_package_key.present?
                           })
        raise ArgumentError, 'Missing personalisation data in Redis'
      rescue Sidekiq::AttrPackageError => e
        Rails.logger.error('VANotify::V2::QueueUserAccountJob AttrPackage error', {
                             error_class: e.class.name,
                             template_id:
                           })
        raise ArgumentError, 'AttrPackage retrieval failed'
      end

      def handle_backend_exception(e)
        if e.status_code == 400
          log_exception_to_rails(e)
        else
          raise e
        end
      end

      def resolve_api_key(api_key_path)
        unless api_key_path.start_with?('Settings.')
          raise ArgumentError, "API key path must start with 'Settings.': #{api_key_path}"
        end

        keys = api_key_path.delete_prefix('Settings.').split('.')
        api_key = Settings.dig(*keys)
        raise ArgumentError, "Unable to resolve API key from path: #{api_key_path}" unless api_key.present?

        api_key
      end
    end
  end
end
