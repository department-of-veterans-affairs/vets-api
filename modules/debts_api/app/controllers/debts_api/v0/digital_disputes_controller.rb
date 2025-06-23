# frozen_string_literal: true

require 'debts_api/v0/digital_dispute_submission_service'

module DebtsApi
  module V0
    class DigitalDisputesController < ApplicationController
      service_tag 'financial-report'

      def create
        StatsD.increment("#{V0::DigitalDispute::STATS_KEY}.initiated")

        result = process_submission

        if result[:success]
          StatsD.increment("#{V0::DigitalDispute::STATS_KEY}.success")
          render json: { message: result[:message] }, status: :ok
        else
          StatsD.increment("#{V0::DigitalDispute::STATS_KEY}.failure")
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      private

      def process_submission
        service = DigitalDisputeSubmissionService.new(current_user, submission_params[:files])
        service.call
      end

      def submission_params
        params.permit(files: [])
      end
    end
  end
end
