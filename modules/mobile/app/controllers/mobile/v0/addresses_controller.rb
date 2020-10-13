# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class AddressesController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      def update
        write_to_vet360_and_render_transaction!(
          'address',
          address_params,
          http_verb: 'put'
        )
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
          :zip_code
        )
      end
    end
  end
end
