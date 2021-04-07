if ActiveRecord::Base.connected? && ActiveRecord::Base.connection.table_exists?("appeals_api_event_subscriptions")
  AppealsApi::Events::Handler.subscribe(:hlr_status_updated, "AppealsApi::StatusUpdated")
  AppealsApi::Events::Handler.subscribe(:nod_status_updated, "AppealsApi::StatusUpdated")
end
