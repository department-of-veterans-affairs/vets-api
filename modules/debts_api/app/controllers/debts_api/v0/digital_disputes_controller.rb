# frozen_string_literal: true

module DebtsApi
  module V0
    class DigitalDisputesController < ApplicationController
      service_tag 'financial-report'

      def create
        StatsD.increment("#{V0::DigitalDispute::STATS_KEY}.initiated")
        digital_dispute = V0::DigitalDispute.new(digital_disputes_params, current_user)
        if digital_dispute.valid?
          # Just returning data back for now while we wait on our integration partner
          render json: digital_dispute.sanitized_json
        else
          StatsD.increment("#{V0::DigitalDispute::STATS_KEY}.failure")
          render json: { errors: digital_dispute.errors }, status: :unprocessable_entity
        end
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
