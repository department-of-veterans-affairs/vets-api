# frozen_string_literal: true

if ActiveRecord::Base.connection.nil? && ActiveRecord::Base.connection.table_exists?('appeals_api_event_subscriptions')
  AppealsApi::Events::Handler.subscribe(:hlr_status_updated, 'AppealsApi::Events::StatusUpdated')
  AppealsApi::Events::Handler.subscribe(:nod_status_updated, 'AppealsApi::Events::StatusUpdated')
end

