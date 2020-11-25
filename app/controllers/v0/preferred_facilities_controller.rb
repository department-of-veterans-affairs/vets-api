# frozen_string_literal: true

module V0
  class PreferredFacilitiesController < ApplicationController
    def index
      render(
        json: current_user.account.preferred_facilities
      )
    end

    def destroy
      render(
        json: current_user.account.preferred_facilities.find(params[:id]).destroy!
      )
    end

    def create
      preferred_facility = PreferredFacility.new(
        params.require(:preferred_facility).permit(:facility_code).merge(
          user: current_user
        )
      )

      if preferred_facility.save
        render(json: preferred_facility)
      else
        raise Common::Exceptions::ValidationErrors, preferred_facility
      end
    end
  end
end
