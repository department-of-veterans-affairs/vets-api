# frozen_string_literal: true

module V0
  class ReferenceDataController < ApplicationController
    def countries
      # TODO: implement
      countries = service.get_countries
      render json: countries
    end

    def intake_sites
      # TODO: implement
    end

    def states
      # TODO: implement
    end

    def disabilities
      # TODO: implement
    end

    def treatment_centers
      # TODO: implement
    end

    private

    def service
      @service ||= EVSS::ReferenceData::Service.new(@current_user)
    end
  end
end
