# frozen_string_literal: true

module V0
  module Profile
    class AddressesController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      def create
        write_to_vet360_and_render_transaction!(
          'address',
          address_params
        )
        Rails.logger.info('AddressesController#create request completed', sso_logging_info)
      end

      def update
        write_to_vet360_and_render_transaction!(
          'address',
          address_params,
          http_verb: 'put'
        )
        Rails.logger.info('AddressesController#update request completed', sso_logging_info)
      end

      def destroy
        write_to_vet360_and_render_transaction!(
          'address',
          add_effective_end_date(address_params),
          http_verb: 'put'
        )
        Rails.logger.info('AddressesController#destroy request completed', sso_logging_info)
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
          :county_code,
          :county_name,
          :validation_key,
          :id,
          :international_postal_code,
          :province,
          :state_code,
          :transaction_id,
          :zip_code,
          :zip_code_suffix
        )
      end
    end
  end
end
