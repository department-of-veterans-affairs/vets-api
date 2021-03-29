# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class SlackNotifier
    include Sidekiq::Worker
    include ActionView::Helpers::DateHelper

    def perform
      return unless Settings.vba_documents.slack.enabled

      fetch_settings
      Rails.logger.info('VBADocuments::SlackNotifier starting.')
      begin
        results = { long_flyers_alerted: long_flyers_alert,
                    upload_stalled_alerted: upload_stalled_alert,
                    daily_notification: daily_notification }
      rescue => e
        results = e
      end
      Rails.logger.info('VBADocuments::SlackNotifier had results', results)
      results
    end

    def fetch_settings
      @slack_url = Settings.vba_documents.slack.notification_url
      @in_flight_hungtime = Settings.vba_documents.slack.in_flight_notification_hung_time_in_days.to_i
      @renotify_time = Settings.vba_documents.slack.renotification_in_minutes.to_i
      @upload_hungtime = Settings.vba_documents.slack.update_stalled_notification_in_minutes.to_i
      @daily_notification_hour = Settings.vba_documents.slack.daily_notification_hour.to_i
    end

    private

    def daily_notification
      hour = Time.now.utc.hour - 5
      if hour.eql?(@daily_notification_hour)
        text = "Daily Status (worst offenders over past week):\n"
        UploadSubmission::IN_FLIGHT_STATUSES.each do |status|
          model = UploadSubmission.aged_processing(0, :days, status).where('created_at > ?', 7.days.ago).first
          next unless model

          start_time = model.metadata['status'][status]['start']
          duration = distance_of_time_in_words(Time.now.to_i - start_time)
          text += "\tStatus \'#{status}\' for #{duration}\n"
        end
        resp = send_to_slack(text)
      end
      resp&.success?
    end

    def upload_stalled_alert
      # spoof_stalled_updates #todo delete me
      alert_on = fetch_stuck_in_state(['uploaded'], @upload_hungtime, :minutes)
      text = 'ALERT!! GUIDS in uploaded for too long!\n'
      alert(alert_on, text)
    end

    def long_flyers_alert
      # spoof_long_flyers #todo delete me
      alert_on = fetch_stuck_in_state(UploadSubmission::IN_FLIGHT_STATUSES, @in_flight_hungtime, :days)
      text = 'ALERT!! GUIDS in flight for too long!\n'
      alert(alert_on, text)
    end

    def send_to_slack(text)
      Faraday.post(@slack_url, "{\"text\": \"#{text}\"}", 'Content-Type' => 'application/json')
    end

    def add_notification_timestamp(models)
      time = Time.now.to_i
      models.each do |m|
        m.metadata['last_slack_notification'] = time
        m.save
      end
    end

    # def spoof_stalled_updates
    # #   # TODO: delete method.
    #   3.times do |i|
    #     u = UploadSubmission.new
    #     status = 'uploaded'
    #     u.status = status
    #     u.save!
    #     u.metadata['status'][status]['start'] = (6 + i).hours.ago.to_i
    #     u.save!
    #   end
    # end

    # def spoof_long_flyers
    #   # TODO: delete method.
    #   UploadSubmission.destroy_all
    #   1.times do |i|
    #     u = UploadSubmission.new
    #     status = 'received'
    #     u.status = status
    #     u.save!
    #     u.metadata['status'][status]['start'] = (15 + i).days.ago.to_i
    #     u.save!
    #   end
    #   3.times do |i|
    #     u = UploadSubmission.new
    #     status = 'processing'
    #     u.status = status
    #     u.save!
    #     u.metadata['status'][status]['start'] = (15 + i).days.ago.to_i
    #     u.save!
    #   end
    #   20.times do |i|
    #     status = 'success'
    #     u = UploadSubmission.new
    #     u.status = status
    #     u.save!
    #     u.metadata['status'][status]['start'] = (15 + i).days.ago.to_i
    #     u.save!
    #   end
    # end

    def alert(alert_on, initial_text)
      guids_found = false
      text = initial_text
      alert_on.each_pair do |status, models|
        text += "#{status.upcase}:\n"
        models.each do |m|
          start_time = m.metadata['status'][status]['start']
          duration = distance_of_time_in_words(Time.now.to_i - start_time)
          text += "\tGUID: #{m.guid} for #{duration}\n"
          guids_found = true
        end
      end
      resp = send_to_slack(text) if guids_found
      add_notification_timestamp(alert_on.values.flatten) if resp&.success?
      resp&.success?
    end

    def fetch_stuck_in_state(states, hungtime, unit_of_measure)
      alerting_on = {}
      states.each do |status|
        alerting_on[status] = UploadSubmission.aged_processing(hungtime, unit_of_measure, status)
                                              .limit(10).select do |m|
          last_notified = m.metadata['last_slack_notification'].to_i # nil to zero
          delta = Time.now.to_i - last_notified
          notify = delta > @renotify_time * 60
          # puts "notify is #{notify} for status #{status} delta is #{delta} with last notified being #{last_notified}"
          notify
        end
      end
      alerting_on
    end
  end
end
# load('./modules/vba_documents/app/workers/vba_documents/slack_notifier.rb')
# SlackNotifier.new.perform
