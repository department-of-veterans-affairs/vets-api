# frozen_string_literal: true

require 'va_profile/models/validation_address'
require 'va_profile/address_validation/service'

module V0
  module Profile
    class AddressValidationController < ApplicationController
      def create
        address = VAProfile::Models::ValidationAddress.new(address_params)
        raise Common::Exceptions::ValidationErrors, address unless address.valid?

        Rails.logger.info('AddressValidationController#create request completed', sso_logging_info)

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
        @service ||= VAProfile::AddressValidation::Service.new
      end
    end
  end
end
