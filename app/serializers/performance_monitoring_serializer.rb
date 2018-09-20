# frozen_string_literal: true

class PerformanceMonitoringSerializer < ActiveModel::Serializer
  attributes :metric, :duration, :page_id

  def id
    nil
  end

  def metric
    object&.name
  end

  def duration
    object&.value
  end

  def page_id
    object&.tags&.first
  end
end
