# frozen_string_literal: true

require_relative '../../../serializers/covid_vaccine/v0/registration_submission_serializer'
require_relative '../../../services/covid_vaccine/v0/facility_suggestion_service'

module CovidVaccine
  module V0
    class FacilitiesController < CovidVaccine::ApplicationController
      skip_before_action :validate_session

      def index
        facilities = CovidVaccine::V0::FacilitySuggestionService.new.facilities_for(params[:zip], count_param)
        render json: CovidVaccine::V0::FacilitySerializer.new(facilities)
      end

      private

      DEFAULT_COUNT = 5

      def count_param
        return DEFAULT_COUNT if params[:count].blank?

        count = params[:count].to_i
        count < 1 || count > 10 ? DEFAULT_COUNT : count
      end
    end
  end
end
