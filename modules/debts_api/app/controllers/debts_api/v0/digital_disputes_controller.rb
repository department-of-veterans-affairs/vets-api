# frozen_string_literal: true

module DebtsApi
  module V0
    class DigitalDisputesController < ApplicationController
      def create
        # Just returning data back for now while we wait on our integration partner
        render json: digital_disputes_params
      end

      private

      def digital_disputes_params
        params.permit(
          veteran_information: {
            contact_information: [
              :email,
              :phone_number,
              :street_address_line_1,
              :street_address_line_2,
              :city
            ]
          },
          debt_information: [
            :debt,
            :dispute_reason,
            :support_statement
          ]
        )
      end
    end
  end
end