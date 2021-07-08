# frozen_string_literal: true

module Webhooks
  class NotificationsJob
    include Sidekiq::Worker
    # load './app/workers/notifications_job.rb'

    def perform
      # lock the rows that will be updated in this job run. The update releases the lock.
      ids = WebhookNotification.lock('FOR UPDATE').where(complete: false, processing: nil).pluck(:id)
      processing_epoch = Time.now.to_i
      WebhookNotification.where(id: ids).update_all(processing: processing_epoch)

      # group the notifications by url
      callback_urls = {}

      WebhookNotification.where(id: ids).each do |notify|
        callback_urls[notify.callback_url] ||= []
        callback_urls[notify.callback_url] << notify.id
      end

      callback_urls.each_pair do |url, ids|
        CallbackUrlJob.perform_async(url, ids)
      end

      # last line calls itself perform_later based on api registration
    end
  end
end
