# frozen_string_literal: true

module VANotify
  class UserAccountJob
    include Sidekiq::Job
    include Vets::SharedLogging
    sidekiq_options retry: 14

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      job_class = msg['class']
      error_class = msg['error_class']
      error_message = msg['error_message']
      args = msg['args']

      template_id = extract_template_id(args)

      callback_metadata = extract_callback_metadata(args)

      context = {
        job_id:,
        job_class:,
        error_class:,
        error_message:,
        template_id:,
        user_account_id: args[0],
        form_number: callback_metadata&.dig('form_number'),
        service: callback_metadata&.dig('statsd_tags', 'service'),
        function: callback_metadata&.dig('statsd_tags', 'function')
      }.compact

      Rails.logger.error("#{job_class} retries exhausted", context)

      tags = build_statsd_tags(template_id, callback_metadata)
      StatsD.increment("sidekiq.jobs.#{job_class.underscore}.retries_exhausted", tags:)
    end

    def perform(
      user_account_id,
      template_id,
      personalisation = nil,
      api_key = Settings.vanotify.services.va_gov.api_key,
      callback_options = nil
    )
      @template_id = template_id # Store for error handling
      user_account = UserAccount.find(user_account_id)
      notify_client = VaNotify::Service.new(api_key, callback_options)

      response = notify_client.send_email(
        {
          recipient_identifier: { id_value: user_account.icn, id_type: 'ICN' },
          template_id:, personalisation:
        }.compact
      )
      StatsD.increment('api.vanotify.user_account_job.success')
      response
    rescue VANotify::Error => e
      handle_backend_exception(e)
    end

    def handle_backend_exception(e)
      if e.status_code == 400
        log_exception_to_rails(e)
        log_malformed_request(e)
      else
        raise e
      end
    end

    def self.extract_template_id(args)
      args[1]&.to_s # Second argument is template_id
    end

    def self.extract_callback_metadata(args)
      callback_options = args[4] # Fifth argument is callback_options
      callback_options.is_a?(Hash) ? callback_options['callback_metadata'] : nil
    end

    def self.build_statsd_tags(template_id, callback_metadata)
      tags = []
      tags << "template_id:#{template_id}" if template_id.present?

      if callback_metadata.is_a?(Hash)
        statsd_tags = callback_metadata['statsd_tags']
        if statsd_tags.is_a?(Hash)
          tags << "service:#{statsd_tags['service']}" if statsd_tags['service'].present?
          tags << "function:#{statsd_tags['function']}" if statsd_tags['function'].present?
        end
      end

      tags
    end

    private

    # Log malformed request (400 error) with template context
    def log_malformed_request(error)
      template_id = @template_id || 'unknown'

      Rails.logger.error(
        'VANotify malformed request (400)',
        {
          template_id:,
          error_message: error.message,
          status_code: error.status_code
        }
      )

      tags = ["template_id:#{template_id}"]
      StatsD.increment('api.vanotify.malformed_request', tags:)
    end
  end
end
