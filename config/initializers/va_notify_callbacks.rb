# frozen_string_literal: true

# Ensure the Callback class for any VANotify Notification is loaded

# require_all uses application root, not autoload paths
require_all 'lib/va_notify/notification_callback'