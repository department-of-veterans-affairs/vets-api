# frozen_string_literal: true

require 'active_support/time'
require 'okta/service'
require 'time'

module AppsApi
  class NotificationService < Common::Client::Base
    def initialize
      @okta_service = Okta::Service.new
      # should match the timing of the AppsApi::FetchConnections job
      @time_period = 60.minutes.ago.utc.iso8601
      @connection_template = Settings.vanotify.services.lighthouse.template_id.connection_template
      @disconnection_template = Settings.vanotify.services.lighthouse.template_id.disconnection_template
      @notify_client = VaNotify::Service.new(Settings.vanotify.services.lighthouse.api_key)
      @connection_event = 'app.oauth2.as.consent.grant'
      @disconnection_event = 'app.oauth2.as.token.revoke'
      @staging_flag = Settings.directory.staging_flag
      @handled_events = []
    end

    def handle_event(event_type, template)
      # @staging_flag is set to false in all environments, except for staging. This will be
      # removed once all testing has been completed in the staging environment
      return if @staging_flag == false

      logs = get_events(event_type)
      logs.body.each do |event|
        unless event_is_invalid?(event)
          parsed_hash = parse_event(event)
          send_email(hash: parsed_hash, template: template)
        end
      end
    end

    def get_events(event_type)
      @okta_service.system_logs(event_type, @time_period)
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
      create_hash(app_record: app_record, user: user, event: event)
    end

    def create_hash(app_record:, user:, event:)
      {
        'uuid' => event['uuid'],
        'app_record' => app_record,
        'user_email' => user.body['profile']['email'],
        'options' => {
          'first_name' => user.body['profile']['firstName'],
          'application' => app_record ? app_record['name'] : nil,
          'time' => format_published_time(event['published']),
          'privacy_policy' => app_record ? app_record['privacy_url'] : nil,
          'password_reset' => Settings.vanotify.links.password_reset,
          'connected_applications_link' => Settings.vanotify.links.connected_applications
        }
      }
    end

    def format_published_time(published)
      # Formats iso8601 time stamp into readable language
      # 2020-11-29T00:23:39.508Z -> 11/29/2020 at 00:23:39:23AM
      Time.zone.parse(published).strftime('%m/%d/%Y at %T:%M%p')
    end

    def event_is_invalid?(event)
      # checking if the event is unable to be processed,
      # or has already been processed.
      event_already_handled?(event['uuid']) || event_unsuccessful?(event)
    end

    def event_already_handled?(uuid)
      @handled_events.include?(uuid)
    end

    def event_unsuccessful?(event)
      event['outcome']['result'] != 'SUCCESS' ||
        (event['eventType'] == @disconnection_event &&
         event['target'][0]['detailEntry']['subject'].nil?)
    end

    def send_email(hash:, template:)
      # will be nil if the application isn't in our directory
      if hash['app_record'].nil?
        false
      else
        @handled_events << hash['uuid']
        @notify_client.send_email(
          email_address: hash['user_email'],
          template_id: template,
          personalisation: hash['options']
        )
      end
    end
  end
end
