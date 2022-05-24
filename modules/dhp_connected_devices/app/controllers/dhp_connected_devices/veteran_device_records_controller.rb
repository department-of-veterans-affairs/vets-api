# frozen_string_literal: true

module DhpConnectedDevices
  class VeteranDeviceRecordsController < ApplicationController
    def index
      device_records = Device.veteran_device_records(@current_user)
      render json: VeteranDeviceRecordSerializer.serialize(device_records[:active], device_records[:inactive])
    end
  end
end
