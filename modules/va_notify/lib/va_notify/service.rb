# frozen_string_literal: true

require 'notifications/client'
require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'
require_relative 'error'
require_relative 'client'
require 'vets/shared_logging'
require 'datadog'

module VaNotify
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    include Vets::SharedLogging

    STATSD_KEY_PREFIX = 'api.vanotify'
    UUID_LENGTH = 36

    configuration VaNotify::Configuration

    attr_reader :notify_client, :callback_options, :template_id

    # API keys for email/SMS often differ from keys for push notifications.
    # Initialize separate service instances with the appropriate API key for each channel type.
    # Each instance only supports the channels its API key is authorized for.
    def initialize(api_key, callback_options = {})
      overwrite_client_networking
      @api_key = api_key
      @notify_client ||= Notifications::Client.new(api_key, client_url)
      @callback_options = callback_options || {}
    rescue => e
      handle_error(e)
    end

    def send_email(args)
      Datadog::Tracing.trace('api.vanotify.service.send_email', service: 'va-notify') do |span|
        span.set_tag('template_id', args[:template_id])

        @template_id = args[:template_id]
        response = with_monitoring do
          if Flipper.enabled?(:va_notify_request_level_callbacks)
            notify_client.send_email(append_callback_url(args))
          else
            notify_client.send_email(args)
          end
        end
        create_notification(response)
        response
      rescue => e
        handle_error(e)
      end
    end

    def send_sms(args)
      @template_id = args[:template_id]
      response = with_monitoring do
        if Flipper.enabled?(:va_notify_request_level_callbacks)
          notify_client.send_sms(append_callback_url(args))
        else
          notify_client.send_sms(args)
        end
      end
      create_notification(response)
      response
    rescue => e
      handle_error(e)
    end

    def send_push(args)
      @template_id = args[:template_id]
      # Push notifications currently do not support notification creation or callbacks
      unless Flipper.enabled?(:va_notify_push_notifications)
        Rails.logger.warn('Push notifications are disabled via feature flag va_notify_push_notifications')
        return nil
      end

      push_client.send_push(args)
    rescue => e
      handle_error(e)
    end

    def push_client
      @push_client ||= VaNotify::Client.new(@api_key, @callback_options)
    end

    private

    def overwrite_client_networking
      perform_lambda = ->(*args) { perform(*args) }

      Notifications::Client::Speaker.class_exec(perform_lambda) do |perform|
        define_method(:open) do |request|
          method = request.method.downcase.to_sym
          path = @base_url + request.path

          response = perform.call(method, path, request.body, request.to_hash)

          response.body = JSON.dump(response.body)
          response
        end
      end
    end

    def client_url
      config.base_path
    end

    def handle_error(error)
      case error
      when Common::Client::Errors::ClientError
        log_error_details(error)
        if error.status >= 400
          context = {
            template_id: callback_options[:template_id] || callback_options['template_id'],
            callback_metadata: sanitize_metadata(
              callback_options[:callback_metadata] || callback_options['callback_metadata']
            )
          }
          raise VANotify::Error.from_generic_error(error, context)
        end
      else
        raise error
      end
    end

    def sanitize_metadata(metadata)
      return nil unless metadata.is_a?(Hash)

      # Specific keys that are safe to include and do not contain PII
      metadata.slice(:notification_type, :form_number)
    end

    def log_error_details(error)
      log_message_to_rails(error.message, 'error', { url: config.base_path, body: error.try(:body) })
    end

    def append_callback_url(args)
      args[:callback_url] = Settings.vanotify.callback_url
      args
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Lint/NonLocalExitFromIterator
    def create_notification(response)
      Datadog::Tracing.trace('api.vanotify.service.create_notification', service: 'va-notify') do |span|
        if response.nil?
          Rails.logger.error('VANotify - no response')
          return
        end

        span.set_tag('notification_id', response.id)

        service_id = set_service_id(response)
        # when the class is used directly we can pass symbols as keys
        # when it comes from a sidekiq job all the keys get converted to strings (because sidekiq serializes it's args)
        notification = VANotify::Notification.new(
          notification_id: response.id,
          source_location: find_caller_locations,
          callback_klass: callback_options[:callback_klass] || callback_options['callback_klass'],
          callback_metadata: callback_options[:callback_metadata] || callback_options['callback_metadata'],
          template_id:,
          service_id:
        )

        if notification.save
          log_notification_success(notification, template_id)
          notification
        else
          log_notification_failed_to_save(notification, template_id)
        end
      rescue => e
        Rails.logger.error(e)
      end
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Lint/NonLocalExitFromIterator

    def log_notification_failed_to_save(notification, template_id)
      Rails.logger.error(
        'VANotify notification record failed to save',
        {
          error_messages: notification.errors,
          template_id:
        }
      )
    end

    def log_notification_success(notification, template_id)
      Rails.logger.info(
        "VANotify notification: #{notification.id} saved",
        {
          source_location: notification.source_location,
          template_id:,
          callback_metadata: notification.callback_metadata,
          callback_klass: notification.callback_klass
        }
      )
    end

    def find_caller_locations
      ignored_files = [
        'modules/va_notify/lib/va_notify/service.rb',
        'va_notify/app/sidekiq/va_notify/email_job.rb',
        'va_notify/app/sidekiq/va_notify/user_account_job.rb',
        'lib/sidekiq/processor.rb',
        'lib/sidekiq/middleware/chain.rb',
        'datadog'
      ]

      caller_locations.each do |location|
        next if ignored_files.any? { |path| location.path.include?(path) }

        return "#{location.path}:#{location.lineno} in #{location.base_label}"
      end
    end

    def set_service_id(response)
      return nil unless Flipper.enabled?(:va_notify_request_level_callbacks)

      template_uri = response&.template&.[]('uri')
      return nil if template_uri.blank?

      uri_segments = template_uri.split('/')
      if uri_segments.length < 5
        Rails.logger.info('VANotify template URI has unexpected format', template_uri:)
        return nil
      end

      uri_segments[4]
    rescue NoMethodError, TypeError => e
      Rails.logger.info('Unable to derive VANotify service_id', error: e.class.name)
      nil
    end
  end
end
