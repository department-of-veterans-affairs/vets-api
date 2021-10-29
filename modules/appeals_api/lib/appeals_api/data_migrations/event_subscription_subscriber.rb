# frozen_string_literal: true

module AppealsApi
  module DataMigrations
    module EventSubscriptionSubscriber
      def self.run
        AppealsApi::Events::Handler.subscribe(:hlr_status_updated, 'AppealsApi::Events::StatusUpdated')
        AppealsApi::Events::Handler.subscribe(:nod_status_updated, 'AppealsApi::Events::StatusUpdated')
        AppealsApi::Events::Handler.subscribe(:sc_status_updated, 'AppealsApi::Events::StatusUpdated')
        AppealsApi::Events::Handler.subscribe(:hlr_received, 'AppealsApi::Events::AppealReceived')
        AppealsApi::Events::Handler.subscribe(:sc_received, 'AppealsApi::Events::AppealReceived')
      end
    end
  end
end
