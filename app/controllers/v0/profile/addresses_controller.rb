# frozen_string_literal: true

module V0
  module Profile
    class AddressesController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      def create
        write_to_vet360_and_render_transaction!('address', address_params)
      end

      def update
        write_to_vet360_and_render_transaction!('address', address_params, http_verb: 'put')
      end

      private

      # rubocop:disable Metrics/MethodLength
      def address_params
        params.permit(
          :address_line1,
          :address_line2,
          :address_line3,
          :address_pou,
          :address_type,
          :city,
          :country,
          :country_code_iso2,
          :country_code_iso3,
          :county_code,
          :county_name,
          :effective_end_date,
          :effective_start_date,
          :id,
          :international_postal_code,
          :province,
          :source_date,
          :state_code,
          :transaction_id,
          :vet360_id,
          :zip_code,
          :zip_code_suffix
        )
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
