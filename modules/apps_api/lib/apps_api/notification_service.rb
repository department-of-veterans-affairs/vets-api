# frozen_string_literal: true

require 'active_support/time'
require 'okta/service'
require 'time'
require 'redis'

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
    end

    def handle_event(event_type, template)
      # @staging_flag is set to false in all environments, except for staging. This will be
      # removed once all testing has been completed in the staging environment
      return if @staging_flag == false

      logs = get_events(event_type)
      logs.body.each do |event|
        parsed_hash = parse_event(event)
        send_email(hash: parsed_hash, template: template) unless event_is_invalid?(parsed_hash, event)
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

    def event_is_invalid?(parsed_hash, event)
      # checking if the event is unable to be processed,
      # or has already been processed.
      event_already_handled?(parsed_hash) || event_unsuccessful?(event)
    end

    def event_already_handled?(parsed_hash)
      already_handled = false
      # get all members of the notification_events set
      members = Redis.smembers('apps_notification_events')
      return false if members.nil?

      handled_events = []
      # check if there is a member with the same email
      # and time as our parsed_hash to detect duplicates
      current_event = { 'email' => parsed_hash[:user_email], 'time' => parsed_hash[:time] }
      members.each do |member|
        member_hash = Redis.hgetall(member)
        already_handled = true if current_event.eql? member_hash
      end
      already_handled
    end

    def event_unsuccessful?(event)
      event['outcome']['result'] != 'SUCCESS' ||
        (event['eventType'] == @disconnection_event &&
         event['target'][0]['detailEntry']['subject'].nil?)
    end

    def mark_event_as_handled(hash)
      # create event and store it in redis
      event = { hash[:uuid] => { email: parsed_hash[:user_email], time: parsed_hash[:time] } }
      Redis.hset('apps_notification_events', event)
      # add redis event to apps_notification_events set so that it is returned as a member
      # when calling #event_already_handled
      Redis.sadd('apps_notification_events', event[:uuid])
    end

    def send_email(hash:, template:)
      # will be nil if the application isn't in our directory
      if hash['app_record'].nil?
        false
      else
        mark_event_as_handled(hash)
        @notify_client.send_email(
          email_address: hash['user_email'],
          template_id: template,
          personalisation: hash['options']
        )
      end
    end
  end
end
