# frozen_string_literal: true

module TravelPay
  class ClaimsController < ApplicationController
    def index
      render json: { data: 'Data!' }, status: 418
    end
  end
end
