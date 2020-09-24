# frozen_string_literal: true

class ServiceHistorySerializer < ActiveModel::Serializer
  attribute :service_history

  def id
    nil
  end

  def service_history
    object
  end
end
