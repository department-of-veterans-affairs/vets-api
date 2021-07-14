# frozen_string_literal: true

module Webhooks
  class CallbackUrlJob
    include Sidekiq::Worker

    def perform(url, ids)
      r = WebhookNotification.where(id: ids)
      msg = { 'notifications' => [] }
      r.each do |notification|
        msg['notifications'] << notification.msg
      end

      Rails.logger.info "Webhooks::CallbackUrlJob Notifying on callback url #{url} for ids #{ids} with msg #{msg}"
      notify(url, msg.to_json)
    end

    private

    def notify(url, msg)
      response = Faraday.post(url, msg, 'Content-Type' => 'application/json')
      record_attempt(response, ids)
    rescue Faraday::ClientError, Faraday::Error => e
      Rails.logger.error("Webhooks::CallbackUrlJob Error in CallbackUrlJob #{e.message}", e)
      record_attempt(e, ids)
    end

    def record_attempt(response, ids)
      ActiveRecord::Base.transaction do
        attempt = WebhookNotificationAttempt.new

        if response.is_a? Exception
          attempt.success = false
          attempt.response = {'exception' => response.message}
        else
          attempt.success = response.success?
          attempt.response = {} #todo set response.body
        end

        # all in a transaction!
        attempt.save!
        attempt_id = attempt.id

        WebhookNotification.where(id: ids).each do |notification|
          a = WebhookNotificationAttemptAssoc.new
          a.webhook_notification_id = notification.id
          a.webhook_notification_attempt_id = attempt_id
          a.save!

          if attempt.success?
            notification.success_attempt_id = attempt_id
          end

          notification.processing = nil
          notification.save!
        end
      end
    end
  end
end
