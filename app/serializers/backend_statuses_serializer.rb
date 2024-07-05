# frozen_string_literal: true

class BackendStatusesSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attributes :reported_at, :statuses, :maintenance_windows

  attribute :maintenance_windows do |object, params|
    maintenance_windows = params[:maintenance_windows]
    return [] unless maintenance_windows

    serializer = MaintenanceWindowSerializer.new(maintenance_windows)
    serialized_windows = serializer.serializable_hash[:data]
    serialized_windows.map { |window| window[:attributes] }
  end
end
