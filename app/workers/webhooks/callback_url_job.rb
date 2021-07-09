# frozen_string_literal: true

module Webhooks
  class CallbackUrlJob
    include Sidekiq::Worker

    def perform(url, ids)
      r = WebhookNotification.where(id: ids)
      msg = { 'batch' => [] }
      r.each do |notification|
        msg['batch'] << notification.msg
      end

      Rails.logger.info "CRIS Notifying on callback url #{url} for ids #{ids} with msg #{msg}"
    rescue => e
      Rails.logger.error("CRIS Error in CallbackUrlJob #{e.message}", e)
    end
  end
end
