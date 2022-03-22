# frozen_string_literal: true

require 'sidekiq'
require_relative '../../../lib/apps_api/notification_service'

module AppsApi
  class FetchConnections
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options unique_for: 24.hours

    def perform
      notif_service = AppsApi::NotificationService.new
      # process all connection events
      notif_service.handle_event(
        'app.oauth2.as.consent.grant',
        Settings.vanotify.services.lighthouse.template_id.connection_template
      )
      # process all disconnection events
      notif_service.handle_event(
        'app.oauth2.as.consent.revoke',
        Settings.vanotify.services.lighthouse.template_id.disconnection_template
      )
    end
  end
end
