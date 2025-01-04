# frozen_string_literal: true

require 'va_profile/models/v3/validation_address'
require 'va_profile/v3/address_validation/service'

module AskVAApi
  module V0
    class AddressValidationController < ApplicationController
      skip_before_action :authenticate
      skip_before_action :verify_authenticity_token
      service_tag 'profile'

      def create
        validation_model = VAProfile::Models::V3::ValidationAddress
        address = validation_model.new(address_params)
        raise Common::Exceptions::ValidationErrors, address unless address.valid?

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
        @service ||= VAProfile::V3::AddressValidation::Service.new
      end
    end
  end
end
