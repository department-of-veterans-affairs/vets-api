# frozen_string_literal: true

class BackendStatusSerializer < ActiveModel::Serializer
  attribute :name
  attribute :is_available

  def id
    nil
  end
end
