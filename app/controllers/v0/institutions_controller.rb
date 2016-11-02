# frozen_string_literal: true
module V0
  class InstitutionsController < ApplicationController
    skip_before_action :authenticate

    # def index
    #   render json: [Institution.all.limit(3).sample]
    # end

    # e.g. /v0/gibct/institutions/autocomplete?term=harv
    #
    def autocomplete
      search_term = params[:term]
      render json: Institution.autocomplete(search_term)
    end

    # e.g. /v0/gibct/institutions/profile?facility_code=31800121
    #
    def profile
      render json: Institution.find_by(facility_code: params[:facility_code])
    end

    def search
      render json: { todo: true }
    end
  end
end
