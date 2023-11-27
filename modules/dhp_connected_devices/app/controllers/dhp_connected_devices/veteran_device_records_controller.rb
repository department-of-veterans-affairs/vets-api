# frozen_string_literal: true

module DhpConnectedDevices
  class VeteranDeviceRecordsController < ApplicationController
    service_tag 'connected-devices'
    def index
      if @current_user&.icn.blank?
        render json: { connectionAvailable: false }
      else
        device_records = Device.veteran_device_records(@current_user)
        device_records_json = VeteranDeviceRecordSerializer.serialize(
          device_records[:active],
          device_records[:inactive]
        )
        device_records_json[:connectionAvailable] = true
        render json: device_records_json
      end
    end
  end
end
