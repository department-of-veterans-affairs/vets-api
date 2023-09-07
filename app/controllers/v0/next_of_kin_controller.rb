# frozen_string_literal: true

module V0
  class NextOfKinController < ApplicationController
    # GET /v0/next_of_kin
    def index
      render(json: service.get_next_of_kin)
    end

    # POST /v0/next_of_kin
    def create
      next_of_kin = VAProfile::Models::AssociatedPerson.new(next_of_kin_params)
      response = service.post_next_of_kin(next_of_kin)
      render(json: response)
    end

    private

    def service
      VAProfile::HealthBenefit::Service.new(current_user)
    end

    def next_of_kin_params
      params.require(:next_of_kin).permit(
        :given_name,
        :family_name,
        :relationship,
        :address_line1,
        :address_line2,
        :address_line3,
        :city,
        :state,
        :zip_code,
        :primary_phone
      )
    end
  end
end
