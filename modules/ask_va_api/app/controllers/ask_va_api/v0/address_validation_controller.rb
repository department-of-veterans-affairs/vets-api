# frozen_string_literal: true

require 'va_profile/models/validation_address'
require 'va_profile/address_validation/service'
require 'va_profile/models/v3/validation_address'
require 'va_profile/v3/address_validation/service'

module AskVAApi
  module V0
    class AddressValidationController < ApplicationController
      skip_before_action :authenticate
      skip_before_action :verify_authenticity_token
      service_tag 'profile'

      def create
        validation_model = Flipper.enabled?(:va_v3_contact_information_service, @current_user) ?
          VAProfile::Models::V3::ValidationAddress : VAProfile::Models::ValidationAddress
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
        @service ||= Flipper.enabled?(:va_v3_contact_information_service, @current_user) ?
        VAProfile::V3::AddressValidation::Service.new : VAProfile::AddressValidation::Service.new
      end
    end
  end
end
