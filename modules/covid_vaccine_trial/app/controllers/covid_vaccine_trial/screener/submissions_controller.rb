# frozen_string_literal: true

# Bypass auth requirements
require_dependency "covid_vaccine_trial/base_controller"

module CovidVaccineTrial
  module Screener
    class SubmissionsController < BaseController
      def create
        form_service = FormService.new

          render json: { status: 'accepted' }, status: :accepted
        else
          error = {
            errors: form_service.submission_errors(payload)
          }
          render json: error, status: 422
          if form_service.valid?(payload)
        end
      end
    end
  end
end