# frozen_string_literal: true

require 'active_support/time'
require 'okta/service'

module AppsApi
  class NotificationService < Common::Client::Base
    def initialize
      @okta_service = Okta::Service.new
      # should match the timing of the AppsApi::FetchConnections job
      @time_period = 60.minutes.ago.utc.iso8601
      @connection_template = Settings.vanotify.template_id.connection_template
      @disconnection_template = Settings.vanotify.template_id.disconnection_template
    end

    def handle_connect
      logs = get_events('app.oauth2.as.consent.grant')
      logs.body.each do |event|
        handle_notification(event, @connection_template)
      end
    end

    def handle_disconnect
      logs = get_events('app.oauth2.as.token.revoke')
      logs.body.each do |event|
        handle_notification(event, @disconnection_template)
      end
    end

    def get_events(event)
      logs = @okta_service.system_logs(event, @time_period)
      logs
    end

    def handle_notification(event, template)
      user_id = event['actor']['id']
      app_id = event['target'].first['detailEntry']['publicclientapp']
      user = @okta_service.user(user_id)
      okta_app = @okta_service.app(app_id)
      app_record = DirectoryApplication.find_by(name: okta_app.body['label'])
      if app_record.present?
        personalisation_hash = {
          'full_name' => event['actor']['displayName'],
          'application' => okta_app.body['label'],
          'time' => event['published'],
          'privacy_policy' => app_record['privacy_url'],
          'password_reset' => Settings.vanotify.links.password_reset,
          'connected_applications_link' => Settings.vanotify.links.connected_applications
        }
        send_email(
          options: personalisation_hash,
          email: user.body['profile']['email'],
          template: template
        )
      end
    end

    def send_email(options:, email:, template:)
      # @notify_client = VaNotify::Service.new
      # @notify_client.send_email(
      # email_address: user.body['profile']['email'],
      # template_id: template,
      # personalisation: personalisation_hash
      # )
    end
  end
end
