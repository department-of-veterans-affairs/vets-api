# frozen_string_literal: true
require 'gi/client'

module V0
  class GiController < ApplicationController
    skip_before_action :authenticate

    def autocomplete
      search_term = params[:term]
      render json: client.get_autocomplete_suggestions(search_term)
    end

    def constants
      render json: client.get_calculator_constants
    end

    # Institution search
    def index
      search_params = whitelisted_search_params
      render json: client.get_search_results(search_params)
    end

    # Institution details
    def show
      facility_code = params[:id]
      render json: client.get_institution_details(facility_code)
    end

    private

    def client
      @client ||= Gi::Client.new
    end

    def whitelisted_search_params
      whitelist = %i(
        name
        page per_page
        type_name school_type
        country state
        student_veteran_group
        yellow_ribbon_scholarship
        principles_of_excellence
        eight_keys_to_veteran_success
      )
      params.select { |k, _v| whitelist.include?(k) }
    end
  end
end
