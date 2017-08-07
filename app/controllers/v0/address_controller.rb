# frozen_string_literal: true
module V0
  class LettersController < ApplicationController
    def show
      response = service.get_address(@current_user)
      render json: response,
        serializer: AddressSerializer
    end

    def update
      response = service.update_address(@current_user)
      render json: response,
        serializer: AddressSerializer
    end

    def countries
      response = service.get_countries(@current_user)
      render json: response,
        serializer: AddressSerializer
    end

    def states
      response = service.get_states(@current_user)
      render json: response,
        serializer: AddressSerializer
    end

    private

    def service
      @service ||= EVSS::PCIUAddress::Service.new
    end
  end
end
