# frozen_string_literal: true

require 'sidekiq'
require_relative '../../../lib/apps_api/notification_service.rb'

module AppsApi
  class FetchConnections
    include Sidekiq::Worker
    include SentryLogging

    def perform
      notif_service = AppsApi::NotificationService.new
      notif_service.handle_connect
      notif_service.handle_disconnect
    end
  end
end
