# frozen_string_literal: true

class ServiceStatusesSerializer < ActiveModel::Serializer
  attributes :reported_at, :statuses

  def id
    nil
  end
end
