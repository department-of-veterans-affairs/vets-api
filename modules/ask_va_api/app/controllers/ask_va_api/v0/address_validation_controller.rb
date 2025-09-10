# frozen_string_literal: true

require 'va_profile/models/validation_address'
require 'va_profile/address_validation/v3/service'

module AskVAApi
  module V0
    class AddressValidationController < ::ApplicationController
      skip_before_action :authenticate
      service_tag 'profile'

      def create
        address = VAProfile::Models::ValidationAddress.new(address_params)

        raise Common::Exceptions::ValidationErrors, address unless address.valid?

        if Settings.vsp_environment == 'staging'
          Rails.logger.info("Staging Address valid: #{address.valid?}, Address POU: #{address.address_pou}")
        end
        Rails.logger.warn('AddressValidationController#create request completed', sso_logging_info)

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
        @service ||= VAProfile::AddressValidation::V3::Service.new
      end
    end
  end
end
