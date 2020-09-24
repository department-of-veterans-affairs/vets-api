# frozen_string_literal: true

module V0
  module MDOT
    class SuppliesController < ApplicationController
      def create
        render(json: client.submit_order(supply_params))
      end

      private

      def address_params
        %i[
          street
          street2
          city
          state
          country
          postal_code
        ]
      end

      def supply_params
        params.permit(
          :use_veteran_address,
          :use_temporary_address,
          :additional_requests,
          :vet_email,
          order: [:product_id],
          permanent_address: address_params,
          temporary_address: address_params
        ).to_hash
      end

      def client
        @client ||= ::MDOT::Client.new(current_user)
      end
    end
  end
end
