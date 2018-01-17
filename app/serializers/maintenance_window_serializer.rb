# frozen_string_literal: true

class MaintenanceWindowSerializer < ActiveModel::Serializer
  attributes :id, :external_service, :start_time, :end_time, :description
end
