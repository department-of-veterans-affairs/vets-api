# frozen_string_literal: true

module V0
  class PerformanceMonitoringsController < ApplicationController
    def create
      response = Benchmark::Performance.by_page_and_metric(metric, duration, page_id)

      render json: response, serializer: PerformanceMonitoringSerializer
    end

    private

    def performance_params
      params.permit(:metric, :duration, :page_id)
    end

    def metric
      performance_params['metric']
    end

    def duration
      performance_params['duration']
    end

    def page_id
      performance_params['page_id']
    end
  end
end
