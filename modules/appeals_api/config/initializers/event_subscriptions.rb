# frozen_string_literal: true

if ActiveRecord::Base.connected? && ActiveRecord::Base.connection.table_exists?('appeals_api_event_subscriptions')
  AppealsApi::Events::Handler.subscribe(:hlr_status_updated, 'AppealsApi::Events::StatusUpdated')
  AppealsApi::Events::Handler.subscribe(:nod_status_updated, 'AppealsApi::Events::StatusUpdated')
end
