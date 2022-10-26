# frozen_string_literal: true

require 'dhp_connected_devices/data_migrations/create_devices'

namespace :data_migration do
  desc 'Creates available connected devices in the database - DhpConnectedDevices'
  task dhp_create_devices: :environment do
    DhpConnectedDevices::DataMigrations::CreateDevices.run
  end
end
