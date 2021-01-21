# frozen_string_literal: true

module V0
  class PreferredFacilitiesController < ApplicationController
    def index
      render(
        json: current_user_preferred_facilities
      )
    end

    def destroy
      render(
        json: destroy_preferred_facility(params[:id])
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

    private

    def destroy_preferred_facility(id)
      preferred_facility = current_user_preferred_facilities.find_by(id: id)
      raise Common::Exceptions::RecordNotFound, id if preferred_facility.blank?

      if preferred_facility.destroy
        preferred_facility
      else
        raise Common::Exceptions::ValidationErrors, preferred_facility
      end
    end

    def current_user_preferred_facilities
      current_user.account.preferred_facilities
    end
  end
end
