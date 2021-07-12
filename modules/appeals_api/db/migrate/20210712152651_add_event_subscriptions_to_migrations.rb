class AddEventSubscriptionsToMigrations < ActiveRecord::Migration[6.1]
  def change
    AppealsApi::Events::Handler.subscribe(:hlr_status_updated, 'AppealsApi::Events::StatusUpdated')
    AppealsApi::Events::Handler.subscribe(:nod_status_updated, 'AppealsApi::Events::StatusUpdated')
    AppealsApi::Events::Handler.subscribe(:hlr_received, 'AppealsApi::Events::AppealReceived')
  end
end
