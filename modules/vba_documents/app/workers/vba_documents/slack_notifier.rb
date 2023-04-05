# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class SlackNotifier
    include Sidekiq::Worker
    include ActionView::Helpers::DateHelper

    # Only retry for ~30 minutes since the job is run every hour
    sidekiq_options retry: 5, unique_for: 1.hour

    AGED_PROCESSING_QUERY_LIMIT = 10
    INVALID_PARTS_QUERY_LIMIT = 10

    def perform
      return unless Settings.vba_documents.slack.enabled

      fetch_settings
      Rails.logger.info('VBADocuments::SlackNotifier starting.')
      begin
        results = { long_flyers_alerted: long_flyers_alert,
                    upload_stalled_alerted: upload_stalled_alert,
                    invalid_parts_alerted: invalid_parts_alert,
                    daily_notification: }
      rescue => e
        results = e
      end
      Rails.logger.info('VBADocuments::SlackNotifier had results', results)
      results
    end

    def fetch_settings
      @in_flight_hungtime = Settings.vba_documents.slack.in_flight_notification_hung_time_in_days.to_i
      @renotify_time = Settings.vba_documents.slack.renotification_in_minutes.to_i
      @upload_hungtime = Settings.vba_documents.slack.update_stalled_notification_in_minutes.to_i
      @daily_notification_hour = Settings.vba_documents.slack.daily_notification_hour.to_i
    end

    private

    def daily_notification
      hour = Time.now.utc.hour + Time.zone_offset('EST') / (60 * 60)
      results = ''

      if hour.eql?(@daily_notification_hour)
        statuses = UploadSubmission::IN_FLIGHT_STATUSES + ['uploaded'] - ['success']
        statuses.each do |status|
          model = UploadSubmission.aged_processing(0, :days, status).where('created_at > ?', 7.days.ago).first
          next unless model

          start_time = model.metadata['status'][status]['start']
          duration = distance_of_time_in_words(Time.now.to_i - start_time)
          results += "\n\tStatus \'#{status}\' for #{duration}"
        end

        notify_slack('Daily Status (worst offenders over past week)', results)
        true
      end
    end

    def upload_stalled_alert
      alert_on = fetch_stuck_in_state(['uploaded'], @upload_hungtime, :minutes)
      message = 'GUIDS in uploaded for too long! (Top 10 shown)'
      alert(alert_on, message)
    end

    def long_flyers_alert
      statuses = UploadSubmission::IN_FLIGHT_STATUSES - ['success']
      alert_on = fetch_stuck_in_state(statuses, @in_flight_hungtime, :days)
      message = 'GUIDS in flight for too long! (Top 10 shown)'
      alert(alert_on, message)
    end

    def invalid_parts_alert
      query_str = "metadata ? 'invalid_parts' and not metadata ? 'invalid_parts_notified'"
      alert_on = UploadSubmission.where(query_str).limit(INVALID_PARTS_QUERY_LIMIT)

      if alert_on.any?
        results = ''
        alert_on.each do |model|
          results += "\n\tGUID: #{model.guid} has invalid parts: #{model.metadata['invalid_parts']}"
        end

        notify_slack('GUIDS with invalid parts submitted! (Top 10 shown)', results.gsub(/"/, "'"))

        alert_on.each do |model|
          model.metadata['invalid_parts_notified'] = true
          model.save!
        end
        true
      end
    end

    def add_notification_timestamp(models)
      time = Time.now.to_i
      models.each do |m|
        m.metadata['last_slack_notification'] = time
        m.save
      end
    end

    def alert(alert_on, message)
      guids_found = false
      results = ''

      alert_on.first.each_pair do |status, models|
        count = alert_on.last[status]
        results += "\n#{status.upcase} (total #{count}):"
        models.each do |m|
          start_time = m.metadata['status'][status]['start']
          duration = distance_of_time_in_words(Time.now.to_i - start_time)
          results += "\n\tGUID: #{m.guid} for #{duration}"
          guids_found = true
        end
      end

      if guids_found
        notify_slack(message, results)
        add_notification_timestamp(alert_on.first.values.flatten)
        true
      end
    end

    def fetch_stuck_in_state(statuses, hungtime, unit_of_measure)
      alerting_on = {}
      status_counts = {}
      statuses.each do |status|
        status_counts[status] = UploadSubmission.aged_processing(hungtime, unit_of_measure, status).count
        alerting_on[status] = UploadSubmission.aged_processing(hungtime, unit_of_measure, status)
                                              .limit(AGED_PROCESSING_QUERY_LIMIT).map do |m|
          last_notified = m.metadata['last_slack_notification'].to_i # nil to zero
          delta = Time.now.to_i - last_notified
          notify = delta > @renotify_time * 60
          [m, notify]
        end
        notify = alerting_on[status].inject(false) { |acu, val| acu || val.last }
        alerting_on[status] = notify ? alerting_on[status].map(&:first) : []
      end
      [alerting_on, status_counts]
    end

    def notify_slack(message, results)
      slack_details = {
        class: self.class.name,
        alert: message,
        details: results
      }
      VBADocuments::Slack::Messenger.new(slack_details).notify!
    end
  end
end
# load('./modules/vba_documents/app/workers/vba_documents/slack_notifier.rb')
# SlackNotifier.new.perform
