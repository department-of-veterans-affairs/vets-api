# frozen_string_literal: true

module Webhooks
  class CallbackUrlJob
    include Sidekiq::Worker

    def perform(url, ids)
      r = WebhookNotification.where(id: ids)
      msg = {'notifications' => []}
      r.each do |notification|
        msg['notifications'] << notification.msg
      end

      Rails.logger.info "Webhooks::CallbackUrlJob Notifying on callback url #{url} for ids #{ids} with msg #{msg}"
      notify(url, msg.to_json)
    end

    private

    def notify(url, msg)
      response = Faraday.post(url, msg, 'Content-Type' => 'application/json')
      if (response.success?)
        Rails.logger.info("Webhooks::CallbackUrlJob response was succesful!! #{response.status}")
        Rails.logger.info("Webhooks::CallbackUrlJob response was succesful!! #{response.body}")
      else
        Rails.logger.info("Webhooks::CallbackUrlJob response was ****NOT**** succesful!! #{response.status}")
        Rails.logger.info("Webhooks::CallbackUrlJob response was ****NOT**** succesful!! #{response.body}")
      end
    rescue Faraday::ClientError, Faraday::Error => e
      Rails.logger.error("Webhooks::CallbackUrlJob Error in CallbackUrlJob #{e.message}", e)
    end
  end
end
