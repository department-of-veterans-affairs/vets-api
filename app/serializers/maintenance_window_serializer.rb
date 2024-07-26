# frozen_string_literal: true

class MaintenanceWindowSerializer
  include JSONAPI::Serializer

  attributes :id, :external_service, :start_time, :end_time, :description
end
