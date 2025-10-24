# frozen_string_literal: true

require 'notifications/client'
require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'
require_relative 'error'
require_relative 'push_client'

module VaNotify
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.vanotify'
    UUID_LENGTH = 36

    configuration VaNotify::Configuration

    attr_reader :notify_client, :push_client, :callback_options, :template_id

    def initialize(api_key, callback_options = {})
      overwrite_client_networking
      @notify_client ||= Notifications::Client.new(api_key, client_url)
      @push_client ||= VaNotify::PushClient.new(api_key, callback_options)
      @callback_options = callback_options || {}
    rescue => e
      handle_error(e)
    end

    def send_email(args)
      @template_id = args[:template_id]
      if Flipper.enabled?(:va_notify_notification_creation)
        response = with_monitoring do
          if Flipper.enabled?(:va_notify_request_level_callbacks)
            notify_client.send_email(append_callback_url(args))
          else
            notify_client.send_email(args)
          end
        end
        create_notification(response)
        response
      else
        with_monitoring do
          notify_client.send_email(args)
        end
      end
    rescue => e
      handle_error(e)
    end

    def send_sms(args)
      @template_id = args[:template_id]
      if Flipper.enabled?(:va_notify_notification_creation)
        response = with_monitoring do
          if Flipper.enabled?(:va_notify_request_level_callbacks)
            notify_client.send_sms(append_callback_url(args))
          else
            notify_client.send_sms(args)
          end
        end
        create_notification(response)
        response
      else
        with_monitoring do
          notify_client.send_sms(args)
        end
      end
    rescue => e
      handle_error(e)
    end

    def send_push(args)
      @template_id = args[:template_id]
      if Flipper.enabled?(:va_notify_notification_creation)
        response = with_monitoring do
          if Flipper.enabled?(:va_notify_request_level_callbacks)
            push_client.send_push(append_callback_url(args))
          else
            push_client.send_push(args)
          end
        end
        create_notification(response)
        response
      else
        with_monitoring do
          push_client.send_push(args)
        end
      end
    rescue => e
      handle_error(e)
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
        save_error_details(error)
        if Flipper.enabled?(:va_notify_custom_errors) && error.status >= 400
          context = {
            template_id: callback_options[:template_id] || callback_options['template_id'],
            callback_metadata: sanitize_metadata(
              callback_options[:callback_metadata] || callback_options['callback_metadata']
            )
          }
          raise VANotify::Error.from_generic_error(error, context)
        elsif error.status >= 400
          raise_backend_exception("VANOTIFY_#{error.status}", self.class, error)
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

    def save_error_details(error)
      Sentry.set_tags(
        external_service: self.class.to_s.underscore
      )

      Sentry.set_extras(
        url: config.base_path,
        message: error.message,
        body: error.body
      )
    end

    def append_callback_url(args)
      args[:callback_url] = Settings.vanotify.callback_url
      args
    end

    def create_notification(response)
      if response.nil?
        Rails.logger.error('VANotify - no response')
        return
      end

      # when the class is used directly we can pass symbols as keys
      # when it comes from a sidekiq job all the keys get converted to strings (because sidekiq serializes it's args)
      notification = VANotify::Notification.new(
        notification_id: response.id,
        source_location: find_caller_locations,
        callback_klass: callback_options[:callback_klass] || callback_options['callback_klass'],
        callback_metadata: callback_options[:callback_metadata] || callback_options['callback_metadata'],
        template_id:,
        service_api_key_path: retrieve_service_api_key_path
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
        'lib/sidekiq/middleware/chain.rb'
      ]

      caller_locations.each do |location|
        next if ignored_files.any? { |path| location.path.include?(path) }

        return "#{location.path}:#{location.lineno} in #{location.base_label}"
      end
    end

    def retrieve_service_api_key_path
      if Flipper.enabled?(:va_notify_request_level_callbacks)
        service_config = Settings.vanotify.services.find do |_service, options|
          # multiple services may be using same options.api_key
          api_key_secret_token = extracted_token(options.api_key)

          api_key_secret_token == @notify_client.secret_token
        end

        if service_config.blank?
          Rails.logger.error("api key path not found for template #{@template_id}")
          nil
        else
          "Settings.vanotify.services.#{service_config[0]}.api_key"
        end
      end
    end

    def extracted_token(computed_api_key)
      computed_api_key[(computed_api_key.length - UUID_LENGTH)..computed_api_key.length]
    end
  end
end
