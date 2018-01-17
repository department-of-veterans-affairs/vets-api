# frozen_string_literal: true

module V0
  class ReferenceDataController < ApplicationController
    def countries
      countries_response = service.get_countries
      render json: countries_response,
             serializer: CountriesSerializer
    end

    def intake_sites
      intake_sites_response = service.get_intake_sites
      render json: intake_sites_response,
             serializer: IntakeSitesSerializer
    end

    def states
      states_response = service.get_states
      render json: states_response,
             serializer: StatesSerializer
    end

    def disabilities
      disabilities_response = service.get_disabilities
      render json: disabilities_response,
             serializer: DisabilitiesSerializer
    end

    def treatment_centers
      state = params[:state].upcase
      treatment_centers_response = service.get_treatment_centers(state)
      render json: treatment_centers_response,
             serializer: TreatmentCentersSerializer
    end

    private

    def service
      @service ||= EVSS::ReferenceData::Service.new(@current_user)
    end
  end
end
