# frozen_string_literal: true

module V0
  class AddressesController < ApplicationController
    before_action { authorize :evss, :access? }

    def show
      response = service.get_address
      render json: response,
             serializer: AddressSerializer
    end

    def update
      address = EVSS::PCIUAddress::Address.build_address(params)
      raise Common::Exceptions::ValidationErrors, address unless address.valid?
      response = service.update_address(address)
      render json: response,
             serializer: AddressSerializer
    end

    def countries
      response = strategy.cache_or_service(:countries) { service.get_countries }
      render json: response,
             serializer: CountriesSerializer
    end

    def states
      response = strategy.cache_or_service(:states) { service.get_states }
      render json: response,
             serializer: StatesSerializer
    end

    def rds_countries
      response = strategy.cache_or_service(:countries) { rds_service.get_countries }
      render json: response,
             serializer: CountriesSerializer
    end

    def rds_states
      response = strategy.cache_or_service(:states) { rds_service.get_states }
      render json: response,
             serializer: StatesSerializer
    end

    private

    def service
      EVSS::PCIUAddress::Service.new(@current_user)
    end

    def rds_service
      EVSS::ReferenceData::Service.new(@current_user)
    end

    def strategy
      EVSS::PCIUAddress::ResponseStrategy.new
    end
  end
end
