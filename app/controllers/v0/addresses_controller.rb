# frozen_string_literal: true

require 'evss/reference_data/service'
require 'evss/pciu_address/service'
require 'evss/pciu_address/response_strategy'

module V0
  class AddressesController < ApplicationController
    before_action { authorize :evss, :access? }

    def show
      response = service.get_address

      render json: response,
             serializer: AddressSerializer
    end

    def update
      address = EVSS::PCIUAddress.build_address(
        params.permit(
          :type, :address_effective_date,
          :address_one, :address_two, :address_three,
          :city, :country_name, :foreign_code,
          :state_code, :zip_code, :zip_suffix,
          :military_post_office_type_code, :military_state_code
        )
      )
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

    private

    def service
      if Settings.evss.reference_data_service&.enabled
        EVSS::ReferenceData::Service.new(@current_user)
      else
        EVSS::PCIUAddress::Service.new(@current_user)
      end
    end

    def strategy
      EVSS::PCIUAddress::ResponseStrategy.new
    end
  end
end
