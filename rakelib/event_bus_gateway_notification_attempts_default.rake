# frozen_string_literal: true

namespace :data_migration do
  task event_bus_gateway_notification_attempts_default: :environment do
    DataMigrations::EventBusGatewayNotificationAttemptsDefault.run
  end
end
