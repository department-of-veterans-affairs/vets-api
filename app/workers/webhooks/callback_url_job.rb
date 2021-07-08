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

      Rails.logger.info "Notifying on callback url #{url} for ids #{ids} with msg #{msg}"
    end
  end
end
