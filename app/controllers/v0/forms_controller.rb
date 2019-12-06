# frozen_string_literal: true

module V0
  class FormsController < ApplicationController
    skip_before_action :authenticate

    def index
      response = Forms::Client.new.get_all
      render json: response.body,
        status: response.status
    end

    def healthcheck
      response = Forms::Client.new.healthcheck
      render json: response.body,
        status: response.status
    end
  end
end
