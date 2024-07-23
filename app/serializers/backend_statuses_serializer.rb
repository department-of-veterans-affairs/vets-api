# frozen_string_literal: true

class BackendStatusesSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attributes :reported_at, :statuses, :maintenance_windows

  attribute :maintenance_windows do |_object, params|
    maintenance_windows = params[:maintenance_windows]
    if maintenance_windows
      serializer = MaintenanceWindowSerializer.new(maintenance_windows)
      serializer.serializable_hash[:data].pluck(:attributes)
    else
      []
    end
  end
end
