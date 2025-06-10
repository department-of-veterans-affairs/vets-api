# frozen_string_literal: true

module V0
  class DatadogActionsController < ApplicationController
    skip_before_action :authenticate_user!
    protect_from_forgery with: :null_session

    def create
      metric = params[:metric]
      tags = params[:tags] || {}

      unless DATADOG_METRIC_ALLOWLIST.include?(metric)
        render json: { error: 'Metric not allowed' }, status: :bad_request and return
      end

      StatsD.increment("frontend.#{metric}", tags: tags.map { |k, v| "#{k}:#{v}" })
      head :accepted
    end
  end
end
