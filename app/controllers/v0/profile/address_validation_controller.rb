# frozen_string_literal: true

module V0
  module Profile
    class AddressValidationController < ApplicationController
      def create
        address = Vet360::Models::ValidationAddress.new(address_params)
        raise Common::Exceptions::ValidationErrors, address unless address.valid?

        render(json: service.address_suggestions(address))
      end

      private

      def address_params
        params.require(:address).permit(
          :address_line1,
          :address_line2,
          :address_line3,
          :address_pou,
          :address_type,
          :city,
          :country_code_iso3,
          :international_postal_code,
          :province,
          :state_code,
          :zip_code,
          :zip_code_suffix
        )
      end

      def service
        @service ||= Vet360::AddressValidation::Service.new
      end
    end
  end
end
