# frozen_string_literal: true

class VeteranDeviceRecordsService
  def self.create_or_activate(user, device_key)
    device = Device.find_by(key: device_key)
    VeteranDeviceRecord
      .find_or_initialize_by(icn: user.icn, device:)
      .update!(active: true)
  end

  def self.deactivate(user, device_key)
    device = Device.find_by(key: device_key)
    VeteranDeviceRecord
      .find_by!(icn: user.icn, device:)
      .update!(active: false)
  end
end
