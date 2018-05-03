# frozen_string_literal: true

module V0
  module Profile
    class AddressesController < ApplicationController
      before_action { authorize :vet360, :access? }

      def create
        address = Vet360::Models::Address.with_defaults(@current_user, address_params)

        if address.valid?
          response    = service.post_address address
          transaction = AsyncTransaction::Vet360::AddressTransaction.start(@current_user, response)

          render json: transaction, serializer: AsyncTransaction::BaseSerializer
        else
          raise Common::Exceptions::ValidationErrors, address
        end
      end

      def update
        address = Vet360::Models::Address.with_defaults(@current_user, address_params)

        if address.valid?
          response    = service.put_address address
          transaction = AsyncTransaction::Vet360::AddressTransaction.start @current_user, response

          render json: transaction, serializer: AsyncTransaction::BaseSerializer
        else
          raise Common::Exceptions::ValidationErrors, address
        end
      end

      private

      def service
        Vet360::ContactInformation::Service.new @current_user
      end

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
          :state_abbr,
          :transaction_id,
          :vet360_id,
          :zip_code,
          :zip_code_suffix
        )
      end
    end
  end
end
