# frozen_string_literal: true

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

        # No domestic or military addresses should have a province but some have been coming in as a string 'null'
        suggested_addresses.each do |sa|
          if sa['address_type'].in?(['DOMESTIC', 'OVERSEAS MILITARY']) && sa['province'].present?
            Rails.logger.info('Mobile Suggested Address - Province in domestic or military address',
                              province: sa['province'])
          end
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
          :country_code_iso3,
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
        VAProfile::AddressValidation::Service.new
      end
    end
  end
end
