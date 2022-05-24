# frozen_string_literal: true

class DeviceSerializer
  def self.serialize(device, active)
    if !device.is_a? Device
      device.map { |d| serialize(d, active) }
    else
      device.as_json(except: :id).merge(urls(device)).merge({ connected: active })
    end
  end

  private_class_method def self.urls(device)
    { authUrl: "/#{device.key}", disconnectUrl: "/#{device.key}/disconnect" }
  end
end
