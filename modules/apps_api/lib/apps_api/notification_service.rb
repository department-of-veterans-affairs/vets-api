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
      @notify_client = VaNotify::Service.new
      @connection_event = 'app.oauth2.as.consent.grant'
      @disconnection_event = 'app.oauth2.as.token.revoke'
    end

    def handle_connect
      logs = get_events(@connection_event)
      logs.body.each do |event|
        unless event_is_invalid(event)
          parsed_hash = parse_event(event)
          send_email(parsed_hash, @connection_template)
        end
      end
    end

    def handle_disconnect
      logs = get_events(@disconnection_event)
      logs.body.each do |event|
        unless event_is_invalid(event)
          parsed_hash = parse_event(event)
          send_email(parsed_hash, @disconnection_template)
        end
      end
    end

    def get_events(event)
      @okta_service.system_logs(event, @time_period)
    end

    def parse_event(event)
      if event['eventType'] == @connection_event
        user_id = event['actor']['id']
        app_id = event['target'].first['detailEntry']['publicclientapp']
        okta_app = @okta_service.app(app_id)
        app_record = DirectoryApplication.find_by(name: okta_app.body['label'])
      else
        user_id = event['target'][0]['detailEntry']['subject']
        app_record = DirectoryApplication.find_by(name: event['actor']['displayName'])
      end
      user = @okta_service.user(user_id)
      create_hash(app_record, user, event)
    end

    def create_hash(app_record:, user:, event:)
      {
        'app_record' => app_record,
        'user_email' => user.body['profile']['email'],
        'options' => {
          'full_name' => event['actor']['displayName'],
          'application' => app_record['name'],
          'time' => event['published'],
          'privacy_policy' => app_record['privacy_url'],
          'password_reset' => Settings.vanotify.links.password_reset,
          'connected_applications_link' => Settings.vanotify.links.connected_applications
        }
      }
    end

    def event_is_invalid(event)
      event['outcome']['result'] != 'SUCCESS' ||
        (event['eventType'] == @disconnection_event &&
          event['target'][0]['detailEntry']['subject'].nil?)
    end

    def send_email(hash:, template:)
      # will be nil if the application isn't in our directory
      unless hash['app_record'].nil?
        @notify_client.send_email(
          email_address: hash['user_email'],
          template_id: template,
          personalisation: hash['options']
        )
      end
    end
  end
end
