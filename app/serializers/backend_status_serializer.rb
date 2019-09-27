# frozen_string_literal: true

class BackendStatusSerializer < ActiveModel::Serializer
  attribute :name
  attribute :service_id
  attribute :is_available
  attribute :uptime_remaining

  def id
    nil
  end
end
