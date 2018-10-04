# frozen_string_literal: true

class PerformanceMonitoringSerializer < ActiveModel::Serializer
  attributes :page_id, :metrics

  def id
    nil
  end

  def page_id
    object[:page_id]
  end

  def metrics
    return [] if object[:response].blank?

    object[:response].map do |stats_d_object|
      {
        metric: stats_d_object&.name,
        duration: stats_d_object&.value
      }
    end
  end
end
