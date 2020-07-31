# frozen_string_literal: true

# Bypass auth requirements
require_dependency "covid_vaccine_trial/base_controller"

module CovidVaccineTrial
  module Screener
    class SubmissionsController < BaseController
      before_action :validate_screener_schema, only: %i[create]

      REQUIRED_PARAMS = [
        :diagnosed, :hospitalized, :smoke, :health_issues, :work_situation,
        :get_to_work, :home_population, :close_contact_count, :first_name,
        :last_name, :email, :phone, :zip, :dob, :gender, :ethnicity
      ].freeze

      TEST_PARAMS = [
        :first_name, :last_name
      ].freeze

      def create
        render json: params_for_create
      end

      private

      def params_for_create
        params.permit(TEST_PARAMS)
      end
    end
  end
end