# frozen_string_literal: true

module V0
  class ReferenceDataController < ApplicationController
    def countries
      countries_response = service.get_countries
      render json: countries_response,
             serializer: CountriesSerializer
    end

    def states
      states_response = service.get_states
      render json: states_response,
             serializer: StatesSerializer
    end

    private

    def service
      @service ||= EVSS::AWS::ReferenceData::Service.new(@current_user)
    end
  end
end
