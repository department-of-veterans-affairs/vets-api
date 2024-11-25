# frozen_string_literal: true

module DebtsApi
  module V0
    class DigitalDisputesController < ApplicationController
      service_tag 'financial-report'

      def create
        # Just returning data back for now while we wait on our integration partner
        render json: digital_disputes_params
      end

      private

      def digital_disputes_params
        params.permit(
          contact_information: %i[
            email
            phone_number
            address_line1
            address_line2
            city
          ],
          debt_information: %i[
            debt
            dispute_reason
            support_statement
          ]
        )
      end
    end
  end
end
