# frozen_string_literal: true

require 'va_profile/address_validation/service'
require 'va_profile/v3/address_validation/service'

module Mobile
  module V0
    class AddressesController < ProfileBaseController
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
        validated_address_params = if Flipper.enabled?(:remove_pciu)
                                     VAProfile::Models::V3::ValidationAddress.new(address_params)
                                   else
                                     VAProfile::Models::ValidationAddress.new(address_params)
                                   end
        raise Common::Exceptions::ValidationErrors, validated_address_params unless validated_address_params.valid?

        response = validation_service.address_suggestions(validated_address_params).as_json
        suggested_addresses = response.dig('response', 'addresses').map do |a|
          address = a['address'].symbolize_keys
          address.merge!(
            id: SecureRandom.uuid,
            address_pou: address_params[:address_pou],
            validation_key: response['response']['validation_key'],
            address_meta: a['address_meta_data'].symbolize_keys
          )

          Mobile::V0::SuggestedAddress.new(address)
        end

        render json: Mobile::V0::SuggestedAddressSerializer.new(suggested_addresses)
      end

      private

      def address_params
        address_params = params.permit(
          :address_line1,
          :address_line2,
          :address_line3,
          :address_pou,
          :address_type,
          :city,
          :country_name,
          :country_code_iso3,
          :county_code, :county_name,
          :id,
          :international_postal_code,
          :province,
          :state_code,
          :validation_key,
          :zip_code,
          :zip_code_suffix
        )

        # No domestic or military addresses should have a province but some have been coming in as a string 'null'
        address_params['province'] = nil if address_params['address_type'].in?(['DOMESTIC', 'OVERSEAS MILITARY'])
        address_params
      end

      def validation_service
        if Flipper.enabled?(:remove_pciu)
          VAProfile::V3::AddressValidation::Service.new
        else
          VAProfile::AddressValidation::Service.new
        end
      end
    end
  end
end
