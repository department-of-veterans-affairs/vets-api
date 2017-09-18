# frozen_string_literal: true
module V0
  class AddressesController < ApplicationController
    def show
      response = service.get_address(@current_user)
      render json: response,
             serializer: AddressSerializer
    end

    def update
      address = EVSS::PCIUAddress::Address.build_address(params)
      raise Common::Exceptions::ValidationErrors, address unless address.valid?
      response = service.update_address(@current_user, address)
      render json: response,
             serializer: AddressSerializer
    end

    def countries
      response = strategy.cache_or_service(:countries) { service.get_countries(@current_user) }
      render json: response,
             serializer: CountriesSerializer
    end

    def states
      response = strategy.cache_or_service(:states) { service.get_states(@current_user) }
      render json: response,
             serializer: StatesSerializer
    end

    private

    def service
      @service ||= EVSS::PCIUAddress::Service.new
    end

    def strategy
      @strategy ||= EVSS::PCIUAddress::ResponseStrategy.new
    end
  end
end
