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
      VAProfile::HealhtBenefit::Service.new(current_user)
    end

    def next_of_kin_params
      # params.permit(...)
    end
  end
end
