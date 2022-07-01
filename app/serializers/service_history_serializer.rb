# frozen_string_literal: true

class ServiceHistorySerializer < ActiveModel::Serializer
  attributes :data_source, :service_history

  def id
    nil
  end

  def data_source
    instance_options[:data_source]
  end

  def service_history
    object
  end
end
