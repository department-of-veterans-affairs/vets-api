# frozen_string_literal: true

class VeteranDeviceRecordSerializer
  def self.serialize(active_devices, inactive_devices)
    {
      devices:
        DeviceSerializer.serialize(active_devices, true) +
          DeviceSerializer.serialize(inactive_devices, false)
    }
  end
end
