# frozen_string_literal: true

# Bypass auth requirements
require_dependency "covid_research/base_controller"

module CovidResearch
  module Volunteer
    class SubmissionsController < BaseController
      STATSD_KEY_PREFIX = STATSD_KEY_PREFIX + '.volunteer'

      def create
        with_monitoring do
          form_service = FormService.new

          if form_service.valid?(payload)
            render json: { status: 'accepted' }, status: :accepted
          else
            StatsD.increment(STATSD_KEY_PREFIX + '.create.fail')

            error = {
              errors: form_service.submission_errors(payload)
            }
            render json: error, status: 422
          end
        end
      end
    end
  end
end