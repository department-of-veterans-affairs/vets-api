# frozen_string_literal: true

require 'sidekiq'
require_relative '../../../lib/apps_api/notification_service'

module AppsApi
  class FetchConnections
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options unique_for: 24.hours

    def perform
      return if cancelled?

      notif_service = AppsApi::NotificationService.new

      # process all disconnection events
      notif_service.handle_event(
        'app.oauth2.as.consent.revoke',
        Settings.vanotify.services.lighthouse.template_id.disconnection_template
      )
    end

    def cancelled?
      Sidekiq.redis do |c|
        if c.respond_to? :exists?
          c.exists?("cancelled-#{jid}")
        else
          c.exists("cancelled-#{jid}")
        end
      end
    end

    def self.cancel!(jid)
      Sidekiq.redis { |c| c.setex("cancelled-#{jid}", 86_400, 1) }
    end
  end
end
