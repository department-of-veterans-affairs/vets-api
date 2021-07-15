# frozen_string_literal: true

require 'appeals_api/data_migrations/event_subscription_subscriber'

namespace :data_migration do
  task appeals_api_event_subscriber: :environment do
    AppealsApi::DataMigrations::EventSubscriptionSubscriber.run
  end
end
