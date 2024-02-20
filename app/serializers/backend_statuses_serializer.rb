# frozen_string_literal: true

class BackendStatusesSerializer < ActiveModel::Serializer
  attributes :reported_at, :statuses, :maintenance_windows

  def id
    nil
  end

  def maintenance_windows
    return [] unless @instance_options[:maintenance_windows]

    ActiveModel::Serializer::CollectionSerializer.new(@instance_options[:maintenance_windows],
                                                      serializer: MaintenanceWindowSerializer)
  end
end
