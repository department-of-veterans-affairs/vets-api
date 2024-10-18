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

    def initialize(api_key, callback_options = nil)
      overwrite_client_networking
      @notify_client ||= Notifications::Client.new(api_key, client_url)
      @callback_options = callback_options
    rescue => e
      handle_error(e)
    end

    def send_email(args)
      caller = caller_locations(1, 1)[0].label
      with_monitoring do
        response = notify_client.send_email(args)
        if callback_options
          VANotify::Notification.new(notification_id: response[:uuid], source_location: caller, callback: callback_options[:callback], metadata: callback_options[:metadata])
        else
          VANotify::Notification.new(notification_id: response[:uuid], source_location: caller)
        end
      end
    rescue => e
      handle_error(e)
    end

    def send_sms(args)
      with_monitoring do
        notify_client.send_sms(args)
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
  end
end
