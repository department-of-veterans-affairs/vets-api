# frozen_string_literal: true

require 'sidekiq'
require_relative '../../../lib/apps_api/notification_service.rb'

module AppsApi
  class FetchConnections
    include Sidekiq::Worker
    include SentryLogging

    def perform
      notif_service = AppsApi::NotificationService.new
      # process all connection events
      notif_service.handle_event(
        'app.oauth2.as.consent.grant',
        Settings.vanotify.template_id.connection_template
      )
      # process all disconnection events
      notif_service.handle_event(
        'app.oauth2.as.token.revoke',
        Settings.vanotify.template_id.disconnection_template
      )
    end
  end
end
