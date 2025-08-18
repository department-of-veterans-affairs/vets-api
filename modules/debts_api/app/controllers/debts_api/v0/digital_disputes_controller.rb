# frozen_string_literal: true

require 'debts_api/v0/digital_dispute_submission_service'

module DebtsApi
  module V0
    class DigitalDisputesController < ApplicationController
      service_tag 'debt-resolution'

      def create
        StatsD.increment("#{V0::DigitalDispute::STATS_KEY}.initiated")

        result = process_submission

        if result[:success]
          StatsD.increment("#{V0::DigitalDispute::STATS_KEY}.success")
          render json: {
            message: result[:message],
            submission_id: result[:submission_id]
          }, status: :ok
        else
          StatsD.increment("#{V0::DigitalDispute::STATS_KEY}.failure")
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      private

      def process_submission
        metadata = parse_metadata

        service = DebtsApi::V0::DigitalDisputeSubmissionService.new(
          current_user,
          submission_params[:files],
          metadata
        )
        service.call
      end

      def parse_metadata
        JSON.parse(submission_params[:metadata], symbolize_names: true)
      end

      def submission_params
        params.permit(
          :metadata,
          files: []
        )
      end
    end
  end
end
