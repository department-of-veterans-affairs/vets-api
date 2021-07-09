# frozen_string_literal: true

module Webhooks
  class NotificationsJob
    include Sidekiq::Worker
    # load './app/workers/webhooks/notifications_job.rb'

    def perform(api_name)
      Rails.logger.info "CRIS NotificationsJob on api_name  #{api_name}"
      # lock the rows that will be updated in this job run. The update releases the lock.
      ids = WebhookNotification.lock('FOR UPDATE').where(complete: false, processing: nil, api_name: api_name).pluck(:id)
      processing_time = Time.now
      WebhookNotification.where(id: ids).update_all(processing: processing_time.to_i)

      # group the notifications by url
      callback_urls = {}

      WebhookNotification.where(id: ids).each do |notify|
        callback_urls[notify.callback_url] ||= []
        callback_urls[notify.callback_url] << notify.id
      end

      callback_urls.each_pair do |url, ids|
        Rails.logger.info "CRIS NotificationsJob on async call  #{url} for #{ids}"
        CallbackUrlJob.perform_async(url, ids)
      end
      Rails.logger.info "CRIS  Webhooks::StartupJob.new.perform  #{processing_time} for #{api_name}"
      Webhooks::SchedulerJob.new.perform(api_name, processing_time) # todo should we put the time in reddis?
    rescue => e
      Rails.logger.error("CRIS Error in NotificationsJob #{e.message}", e)
    end
  end
end
