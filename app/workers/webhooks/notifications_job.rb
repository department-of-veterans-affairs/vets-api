# frozen_string_literal: true

module Webhooks
  class NotificationsJob
    include Sidekiq::Worker
    # load './app/workers/webhooks/notifications_job.rb'

    def perform(api_name)
      job_id = nil
      processing_time = Time.current
      max_retries = Webhooks::Utilities.api_name_to_retries[api_name]
      Rails.logger.info "Webhooks::NotificationsJob on api_name  #{api_name}"
      # lock the rows that will be updated in this job run. The update releases the lock.
      # rubocop:disable Rails/SkipsModelValidations
      ids = Webhooks::Notification.lock('FOR UPDATE').where(final_attempt_id: nil, processing: nil,
                                                            api_name:).pluck(:id)
      Webhooks::Notification.where(id: ids).update_all(processing: processing_time.to_i)
      # rubocop:enable Rails/SkipsModelValidations

      # group the notifications by url
      callback_urls = get_callback_urls(ids)
      callback_urls.each_pair do |url, notify_ids|
        Rails.logger.info "Webhooks::NotificationsJob on async call  #{url} for #{notify_ids}"
        CallbackUrlJob.perform_async(url, notify_ids, max_retries)
      end

      Rails.logger.info "Webhooks::NotificationsJob Webhooks::StartupJob.new.perform #{processing_time} for #{api_name}"
      -> { job_id } # Used under test
    rescue => e
      Rails.logger.error("Webhooks::NotificationsJob Error in NotificationsJob #{e.message}", e)
    ensure
      job_id = Webhooks::SchedulerJob.new.perform(api_name, processing_time) # should we put the time in reddis?
    end

    private

    def get_callback_urls(ids)
      callback_urls = {}

      Webhooks::Notification.where(id: ids).each do |notify|
        callback_urls[notify.callback_url] ||= []
        callback_urls[notify.callback_url] << notify.id
      end
      callback_urls
    end
  end
end
