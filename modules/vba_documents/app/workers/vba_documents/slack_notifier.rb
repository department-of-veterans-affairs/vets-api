# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class SlackNotifier
    include Sidekiq::Worker
    include ActionView::Helpers::DateHelper

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
                    daily_notification: daily_notification }
      rescue => e
        results = e
      end
      Rails.logger.info('VBADocuments::SlackNotifier had results', results)
      results
    end

    def fetch_settings
      @default_alert_url = Settings.vba_documents.slack.default_alert_url
      @invalid_parts_alert_url = Settings.vba_documents.slack.invalid_parts_alert_url
      @in_flight_hungtime = Settings.vba_documents.slack.in_flight_notification_hung_time_in_days.to_i
      @renotify_time = Settings.vba_documents.slack.renotification_in_minutes.to_i
      @upload_hungtime = Settings.vba_documents.slack.update_stalled_notification_in_minutes.to_i
      @daily_notification_hour = Settings.vba_documents.slack.daily_notification_hour.to_i
    end

    private

    def daily_notification
      hour = Time.now.utc.hour + Time.zone_offset('EST') / (60 * 60)
      if hour.eql?(@daily_notification_hour)
        text = "Daily Status (worst offenders over past week):\n"
        statuses = UploadSubmission::IN_FLIGHT_STATUSES + ['uploaded'] - ['success']
        statuses.each do |status|
          model = UploadSubmission.aged_processing(0, :days, status).where('created_at > ?', 7.days.ago).first
          next unless model

          start_time = model.metadata['status'][status]['start']
          duration = distance_of_time_in_words(Time.now.to_i - start_time)
          text += "\tStatus \'#{status}\' for #{duration}\n"
        end
        resp = send_to_slack(text, @default_alert_url)
      end
      resp&.success?
    end

    def upload_stalled_alert
      alert_on = fetch_stuck_in_state(['uploaded'], @upload_hungtime, :minutes)
      text = 'ALERT - GUIDS in uploaded for too long! (Top 10 shown)\n'
      alert(alert_on, text)
    end

    def long_flyers_alert
      statuses = UploadSubmission::IN_FLIGHT_STATUSES - ['success']
      alert_on = fetch_stuck_in_state(statuses, @in_flight_hungtime, :days)
      text = 'ALERT - GUIDS in flight for too long! (Top 10 shown)\n'
      alert(alert_on, text)
    end

    def invalid_parts_alert
      query_str = "metadata ? 'invalid_parts' and not metadata ? 'invalid_parts_notified'"
      alert_on = UploadSubmission.where(query_str).limit(INVALID_PARTS_QUERY_LIMIT)
      text = 'ALERT - GUIDS with invalid parts submitted! (Top 10 shown)\n'
      alert_on.each do |model|
        text += "\tGUID: #{model.guid} has invalid parts: #{model.metadata['invalid_parts']}\n"
      end
      text = text.gsub(/"/, "'")
      resp = send_to_slack(text, @invalid_parts_alert_url) if alert_on.any?
      if resp&.success?
        alert_on.each do |model|
          model.metadata['invalid_parts_notified'] = true
          model.save!
        end
      end
      resp&.success?
    end

    def send_to_slack(text, url)
      Faraday.post(url, "{\"text\": \"#{text}\"}", 'Content-Type' => 'application/json')
    end

    def add_notification_timestamp(models)
      time = Time.now.to_i
      models.each do |m|
        m.metadata['last_slack_notification'] = time
        m.save
      end
    end

    def alert(alert_on, initial_text)
      guids_found = false
      text = initial_text
      alert_on.first.each_pair do |status, models|
        count = alert_on.last[status]
        text += "#{status.upcase} (total #{count}):\n"
        models.each do |m|
          start_time = m.metadata['status'][status]['start']
          duration = distance_of_time_in_words(Time.now.to_i - start_time)
          text += "\tGUID: #{m.guid} for #{duration}\n"
          guids_found = true
        end
      end
      resp = send_to_slack(text, @default_alert_url) if guids_found
      add_notification_timestamp(alert_on.first.values.flatten) if resp&.success?
      resp&.success?
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
  end
end
# load('./modules/vba_documents/app/workers/vba_documents/slack_notifier.rb')
# SlackNotifier.new.perform
