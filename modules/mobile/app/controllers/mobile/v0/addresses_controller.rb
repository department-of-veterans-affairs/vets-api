# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'vet360/address_validation/service'

module Mobile
  module V0
    class AddressesController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      skip_after_action :invalidate_cache, only: [:validation]

      def create
        transaction = service.save_and_await_response(resource_type: 'address', params: address_params)
        render json: transaction, serializer: AsyncTransaction::BaseSerializer
      end

      def update
        transaction = service.save_and_await_response(resource_type: 'address', params: address_params, update: true)
        render json: transaction, serializer: AsyncTransaction::BaseSerializer
      end

      def validate
        address = Vet360::Models::ValidationAddress.new(address_params)
        raise Common::Exceptions::ValidationErrors, address unless address.valid?

        response = validation_service.address_suggestions(address).as_json['response']
        suggested_addresses = response['addresses'].map do |a|
          OpenStruct.new(a['address'].merge(
                           'id' => SecureRandom.uuid,
                           'meta' => a['address_meta_data'].merge('validation_key' => response['validation_key'])
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

      def service
        Mobile::V0::Profile::SyncUpdateService.new(@current_user)
      end

      def validation_service
        @service ||= Vet360::AddressValidation::Service.new
      end
    end
  end
end
