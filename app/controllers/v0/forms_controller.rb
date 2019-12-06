# frozen_string_literal: true

module V0
  class FormsController < ApplicationController
    skip_before_action :authenticate

    def index
      response = Forms::Service.new.get_all
      render json: response.body
    end
  end
end
