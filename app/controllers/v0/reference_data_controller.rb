# frozen_string_literal: true

module V0
  class ReferenceDataController < ApplicationController
    def countries
      # TODO: implement
      render json: {test: 'test'}
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
      @service ||= EVSS::ReferenceData::Service.new(EVSS::Jwt.new(@current_user).encode)
    end
  end
end
