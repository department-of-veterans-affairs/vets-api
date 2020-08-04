# frozen_string_literal: true

# Bypass auth requirements
require_dependency "covid_vaccine_trial/base_controller"

module CovidVaccineTrial
  module Screener
    class SubmissionsController < BaseController
      REQUIRED_PARAMS = [
        :diagnosed, :hospitalized, :smoke, :health_issues, :work_situation,
        :get_to_work, :home_population, :close_contact_count, :first_name,
        :last_name, :email, :phone, :zip, :dob, :gender, :ethnicity
      ].freeze

      TEST_PARAMS = [
        :first_name, :last_name
      ].freeze

      def create
        form_service = FormService.new

        if form_service.valid_submission?(payload)
          render json: { status: 'accepted' }
        else
          error = {
            errors: form_service.submission_errors(payload)
          }
          render json: error, status: 422
        end
      end
    end
  end
end