# frozen_string_literal: true

require 'dhp_connected_devices/data_migrations/reset_all_veteran_fitbit_records'

namespace :data_migration do
  desc 'Warning: This task resets ALL Veteran records to show they do not have a Fitbit device connected'
  task dhp_reset_all_veteran_fitbit_device_records: :environment do
    raise 'This task should not be run in production' if Settings.vsp_environment == 'production'

    DhpConnectedDevices::DataMigrations::ResetAllVeteranFitbitRecords.run
  end
end
