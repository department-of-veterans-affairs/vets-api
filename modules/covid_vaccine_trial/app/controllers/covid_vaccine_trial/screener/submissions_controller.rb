# frozen_string_literal: true

# Bypass auth requirements
require_dependency "covid_vaccine_trial/base_controller"

module CovidVaccineTrial
  module Screener
    class SubmissionsController < BaseController
      def create
        with_monitoring do
          form_service = FormService.new

          if form_service.valid?(payload)
            render json: { status: 'accepted' }, status: :accepted
          else
            StatsD.increment('api.covid-vaccine.create.fail')

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