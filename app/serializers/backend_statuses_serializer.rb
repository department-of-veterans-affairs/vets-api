# frozen_string_literal: true

class BackendStatusesSerializer < ActiveModel::Serializer
  attributes :reported_at, :statuses

  def id
    nil
  end
end
