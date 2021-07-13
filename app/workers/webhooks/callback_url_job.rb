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

      Rails.logger.info "CRIS Notifying on callback url #{url} for ids #{ids} with msg #{msg}"
      notify(url, msg.to_json)
    end

    private

    def notify(url, msg)
      response = Faraday.post(url, msg, 'Content-Type' => 'application/json')
      # if (response.success?)
      #
      # else
      #
      # end
    rescue Faraday::ClientError, Faraday::Error => e
      Rails.logger.error("CRIS Error in CallbackUrlJob #{e.message}", e)
    end
  end
end
