# frozen_string_literal: true

module V0
  module MDOT
    class SuppliesController < ApplicationController
      def create
        render(json: client.submit_order(supply_params))
      end

      private

      def supply_params
        params.permit(
          :use_permanent_address,
          :use_temporary_address,
          :additional_requests,
          order: [:product_id],
          permanent_address: %i[
            street
            street2
            city
            state
            country
            postal_code
          ]
        ).to_hash
      end

      def client
        @client ||= ::MDOT::Client.new(current_user)
      end
    end
  end
end
