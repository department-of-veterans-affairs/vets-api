# frozen_string_literal: true

require 'active_support/time'
require 'okta/service'
require 'time'
require 'redis'

module AppsApi
  class NotificationService < Common::Client::Base
    def initialize
      @okta_service = Okta::Service.new
      # twice as large as the AppsApi::FetchConnections job to account for queuing time
      @time_period = 120.minutes.ago.utc.iso8601
      @connection_template = Settings.vanotify.services.lighthouse.template_id.connection_template
      @disconnection_template = Settings.vanotify.services.lighthouse.template_id.disconnection_template
      @notify_client = VaNotify::Service.new(Settings.vanotify.services.lighthouse.api_key)
      @connection_event = 'app.oauth2.as.consent.grant'
      @disconnection_event = 'app.oauth2.as.consent.revoke'
      @should_perform = Settings.directory.notification_service_flag || false
    end

    def handle_event(event_type, template)
      return 'not enabled for this environment' unless @should_perform

      logs = get_events(event_type)
      logs.body.each do |event|
        parsed_hash = parse_event(event)
        send_email(hash: parsed_hash, template:) unless event_is_invalid?(parsed_hash, event)
      end
    end

    def get_events(event_type)
      @okta_service.system_logs(event_type, @time_period)
    end

    def parse_event(event)
      user_id = event['target'].first['detailEntry']['user']
      app_id = event['target'].first['detailEntry']['publicclientapp']
      okta_app = @okta_service.app(app_id)
      app_record = DirectoryApplication.find_by(name: okta_app.body['label'])
      user = @okta_service.user(user_id)
      create_hash(app_record:, user:, event:)
    end

    def create_hash(app_record:, user:, event:)
      {
        uuid: event['uuid'],
        app_record:,
        user_email: user.body['profile']['email'],
        options: {
          first_name: user.body['profile']['firstName'],
          application: app_record ? app_record['name'] : nil,
          time: format_published_time(event['published']),
          privacy_policy: app_record ? app_record['privacy_url'] : nil,
          password_reset: Settings.vanotify.links.password_reset,
          connected_applications_link: Settings.vanotify.links.connected_applications
        }
      }
    end

    def format_published_time(published)
      # Formats iso8601 time stamp into readable language
      # 2020-11-29T00:23:39.508Z -> 11/29/2020 at 12:23 a.m
      Time.zone.parse(published).strftime('%m/%d/%Y at %I:%M %P').sub(/([ap])m/, '\1.m')
    end

    def event_is_invalid?(parsed_hash, event)
      # checking if the event is unable to be processed,
      # or has already been processed.
      event_already_handled?(parsed_hash) || event_unsuccessful?(event)
    end

    def event_already_handled?(parsed_hash)
      # get all members of the notification_events set
      members = $redis.smembers('apps_notification_events')
      return false if members.nil?

      # check if there is a member with the same email
      # and time as our parsed_hash to detect duplicates
      current_event = { 'email' => parsed_hash[:user_email], 'time' => parsed_hash[:options][:time] }
      members.each do |member|
        member_hash = $redis.hgetall(member)
        $redis.srem('apps_notification_events', member) if member_hash.blank?

        return true if current_event.eql? member_hash
      end
      false
    end

    def event_unsuccessful?(event)
      event['outcome']['result'] != 'SUCCESS'
    end

    def mark_event_as_handled(hash)
      # create event hash and store it in redis
      $redis.hmset(hash[:uuid], 'email', hash[:user_email], 'time', hash[:options][:time])
      # add redis event to apps_notification_events set so that it is returned as a member
      # when calling #event_already_handled
      $redis.sadd('apps_notification_events', hash[:uuid])
      # set key to expire in 3 hours. 60 seconds * 180 minutes = 10800 seconds
      $redis.expire(hash[:uuid], 10_800)
    end

    def send_email(hash:, template:)
      # will be nil if the application isn't in our directory
      if hash[:app_record].nil?
        false
      else
        mark_event_as_handled(hash)
        @notify_client.send_email(
          email_address: hash[:user_email],
          template_id: template,
          personalisation: hash[:options]
        )
      end
    end
  end
end
