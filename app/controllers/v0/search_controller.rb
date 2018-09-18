# frozen_string_literal: true

module V0
  class SearchController < ApplicationController
    skip_before_action :authenticate

    def index
      response = Search::Service.new(params['query']).results

      render json: response, serializer: SearchSerializer
    end
  end
end
