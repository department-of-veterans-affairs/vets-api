# frozen_string_literal: true
module V0
  class InstitutionsController < ApplicationController
    skip_before_action :authenticate

    # search
    def index
      render json: { todo: true }
    end

    def show
      render json: Institution.find_by(facility_code: params[:id])
    end

    # GET /v0/gibct/institutions/autocomplete?term=harv
    def autocomplete
      search_term = params[:term]
      render json: Institution.autocomplete(search_term)
    end
  end
end
