# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class SlackNotifier
    include Sidekiq::Worker
    include ActionView::Helpers::DateHelper

    SLACK_URL = Settings.vba_documents.slack_notification_url
    ALERT_LOOKBACK = Settings.vba_documents.slack_notification_lookback_in_days.to_i

    def perform
      spoof_long_flyers
      text = 'ALERT!!\n'
      alert_on = fetch_long_flyers
      alert_on.each_pair do |status,models|
        text = text + "#{status.upcase}:\n"
        models.each do |m|
          start_time = m.metadata['status'][status]['start']
          start_time = start_time - ALERT_LOOKBACK.days #todo remove line
          puts Time.now.to_i - start_time
          duration = distance_of_time_in_words(Time.now.to_i - start_time)
          text = text + "\tGUID: #{m.guid} for approximately #{duration}\n"
        end
      end
      resp = send_to_slack(text)
      if resp.success?
        add_notification_timestamp(alert_on.values.flatten)
      end
    end

    private

    def send_to_slack(text)
      Faraday.post(SLACK_URL, "{\"text\": \"#{text}\"}", "Content-Type" => "application/json")
    end

    def add_notification_timestamp(models)
      models.each do |m|
        m.metadata['last_slack_notification'] ||= {}
        m.metadata['last_slack_notification'] = Time.now.to_i
        m.save
      end
    end

    def spoof_long_flyers
      UploadSubmission.destroy_all
      UploadSubmission::IN_FLIGHT_STATUSES.each do |status|
        2.times do
          u = UploadSubmission.new
          u.status = status
          u.created_at = 15.days.ago
          u.save!
        end
      end
    end

    def fetch_long_flyers
      alerting_on = {}
      UploadSubmission::IN_FLIGHT_STATUSES.each do |status|
        alerting_on[status] = UploadSubmission.aged_processing(ALERT_LOOKBACK, status)
      end
      alerting_on
    end

  end
end
=begin
load('./modules/vba_documents/app/workers/vba_documents/slack_notifier.rb')
SlackNotifier.new.perform
=end