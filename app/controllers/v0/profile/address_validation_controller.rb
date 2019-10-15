module V0
  module Profile
    class AddressValidationController < ApplicationController
      def create
        render(json: service.address_suggestions(Vet360::Models::Address.new(address_params)))
      end

      private

      def address_params
        params.permit(
          :address_line1,
          :address_line2,
          :address_line3,
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
