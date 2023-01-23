# frozen_string_literal: true

class ServiceHistorySerializer < ActiveModel::Serializer
  attributes :service_history

  def id
    nil
  end

  def service_history
    object
  end
end
