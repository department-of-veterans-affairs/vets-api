# frozen_string_literal: true

module V0
  class FormsController < ApplicationController
    skip_before_action :authenticate

    def index
      response = Forms::Client.new.get_all
      render json: response.body,
             status: response.status
    end

    def query_params
      params.permit(:query)
    end

    def query
      sanitize query_params['query']
    end

  end
end
