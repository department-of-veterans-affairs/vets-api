# frozen_string_literal: true

require 'notifications/client'
require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'

module VaNotify
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.vanotify'

    configuration VaNotify::Configuration

    attr_reader :notify_client, :callback_options

    def initialize(api_key, callback_options = {})
      overwrite_client_networking
      @notify_client ||= Notifications::Client.new(api_key, client_url)
      @callback_options = callback_options || {}
    rescue => e
      handle_error(e)
    end

    def send_email(args)
      if Flipper.enabled?(:va_notify_notification_creation)
        response = with_monitoring do
          notify_client.send_email(args)
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
      if Flipper.enabled?(:va_notify_notification_creation)
        response = with_monitoring do
          notify_client.send_sms(args)
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
        raise_backend_exception("VANOTIFY_#{error.status}", self.class, error) if error.status >= 400
      else
        raise error
      end
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

    def create_notification(response)
      if response.nil?
        Rails.logger.error('VANotify - no response')
        return
      end

      notification = VANotify::Notification.new(
        notification_id: response.id,
        source_location: find_caller_locations,
        callback: callback_options[:callback],
        callback_metadata: callback_options[:callback_metadata]
      )

      if notification.save
        notification
      else
        log_notification_failed_to_save(notification)
      end
    rescue => e
      Rails.logger.error(e)
    end

    def log_notification_failed_to_save(notification)
      Rails.logger.error(
        'VANotify notification record failed to save',
        {
          error_messages: notification.errors
        }
      )
    end

    def find_caller_locations
      va_notify_classes = [
        'modules/va_notify/lib/va_notify/service.rb',
        'va_notify/app/sidekiq/va_notify/email_job.rb',
        'va_notify/app/sidekiq/va_notify/user_account_job.rb'
      ]

      caller_locations.each do |location|
        next if va_notify_classes.any? { |path| location.path.include?(path) }

        return "#{location.path}:#{location.lineno} in #{location.label}"
      end
    end
  end
end
