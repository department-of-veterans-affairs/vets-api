# frozen_string_literal: true

module V0
  class VaFormsController < ApplicationController
    skip_before_action :authenticate

    def index
      response = VaForms::Service.new.get_all
      render json: response.body
    end
  end
end
