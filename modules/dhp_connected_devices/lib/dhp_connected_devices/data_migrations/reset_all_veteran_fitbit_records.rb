# frozen_string_literal: true

module DhpConnectedDevices
  module DataMigrations
    module ResetAllVeteranFitbitRecords
      module_function

      def run
        # Warning! this will reset ALL veteran records to show they do not have a fitbit connected to their account
        VeteranDeviceRecord.where(device_id: Device.find_by(key: 'fitbit')).update(active: false)
      end
    end
  end
end
