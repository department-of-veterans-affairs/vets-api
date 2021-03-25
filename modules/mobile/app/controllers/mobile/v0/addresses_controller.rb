# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'va_profile/address_validation/service'

module Mobile
  module V0
    class AddressesController < ProfileBaseController
      skip_after_action :invalidate_cache, only: [:validation]

      def create
        render_transaction_to_json(
          service.save_and_await_response(resource_type: :address, params: address_params)
        )
      end

      def update
        render_transaction_to_json(
          service.save_and_await_response(resource_type: :address, params: address_params, update: true)
        )
      end

      def destroy
        delete_params = address_params.to_h.merge(effective_end_date: Time.now.utc.iso8601)
        render_transaction_to_json(
          service.save_and_await_response(resource_type: :address, params: delete_params, update: true)
        )
      end

      def validate
        address = VAProfile::Models::ValidationAddress.new(address_params)
        raise Common::Exceptions::ValidationErrors, address unless address.valid?

        response = validation_service.address_suggestions(address).as_json
        suggested_addresses = response.dig('response', 'addresses').map do |a|
          OpenStruct.new(a['address'].merge(
                           'id' => SecureRandom.uuid,
                           'address_pou' => address_params[:address_pou],
                           'validation_key' => response['response']['validation_key'],
                           'address_meta' => a['address_meta_data']
                         ))
        end

        render json: Mobile::V0::SuggestedAddressSerializer.new(suggested_addresses)
      end

      private

      def address_params
        params.permit(
          :address_line1,
          :address_line2,
          :address_line3,
          :address_pou,
          :address_type,
          :city,
          :country_code_iso3,
          :id,
          :international_postal_code,
          :province,
          :state_code,
          :validation_key,
          :zip_code,
          :zip_code_suffix
        )
      end

      def validation_service
        VAProfile::AddressValidation::Service.new
      end
    end
  end
end
