# frozen_string_literal: true

module V0
  class PerformanceMonitoringsController < ApplicationController
    def create
      response = Benchmark::Performance.metrics_for_page(page_id, metrics_data)

      render json: { page_id: page_id, response: response }, serializer: PerformanceMonitoringSerializer
    end

    private

    def performance_params
      params.permit(:page_id, metrics: [:metric, :duration])
    end

    def page_id
      performance_params['page_id']
    end

    def metrics_data
      performance_params['metrics']
    end
  end
end
