# frozen_string_literal: true

module V0
  class DatadogActionController < ApplicationController
    skip_before_action :authenticate

    def create
      metric = params[:metric]
      tags = params[:tags] || []

      unless DatadogMetrics::ALLOWLIST.include?(metric)
        render json: { error: 'Metric not allowed' }, status: :bad_request and return
      end

      StatsD.increment("web.frontend.#{metric}", tags:)
      head :no_content
    end
  end
end
