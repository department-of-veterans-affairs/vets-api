# this file is necessary for the namespaced module initializer to function
ActiveRecord::Base.connected? && ActiveRecord::Base.connection.table_exists?('appeals_api_event_subscriptions')

