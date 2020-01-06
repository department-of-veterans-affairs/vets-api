# frozen_string_literal: true

# rubocop:disable Layout/LineLength
module V0
  class PerformanceMonitoringsController < ApplicationController
    skip_before_action :authenticate

    # Calls StatsD.measure for a given whitelisted path, and set of metrics data.
    #
    # Params require a :data attribute that contain a JSON string of metrics data.
    #   For example:
    #   {
    #     "data" => "{\"page_id\":\"/\",\"metrics\":[{\"metric\":\"initial_page_load\",\"duration\":1234.56},{\"metric\":\"time_to_paint\",\"duration\":123.45}]}",
    #     ...
    #   }
    # @see For whitelisted paths: lib/benchmark/whitelist.rb
    #
    def create
      response = Benchmark::Performance.metrics_for_page(page_id, metrics_data)

      render json: { page_id: page_id, response: response }, serializer: PerformanceMonitoringSerializer
    end

    private

    def page_id
      strong_params['page_id']
    end

    def metrics_data
      strong_params['metrics']
    end

    def strong_params
      new_params = ActionController::Parameters.new(parsed_params)

      new_params.permit(:page_id, metrics: %i[metric duration])
    end

    def parsed_params
      JSON.parse performance_params
    end

    def performance_params
      params.require(:data)
    end
  end
end
# rubocop:enable Layout/LineLength
