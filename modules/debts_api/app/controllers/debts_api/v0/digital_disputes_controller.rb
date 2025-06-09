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
      rescue => e
        StatsD.increment("#{V0::DigitalDispute::STATS_KEY}.failure")
        Rails.logger.error "Digital dispute submission failed: #{e.message}"
        render json: { errors: { base: ['An error occurred processing your submission'] } },
               status: :internal_server_error
      end

      private

      def process_submission
        service = DigitalDisputeSubmissionService.new(submission_params[:files])
        service.call
      end

      def submission_params
        params.permit(files: [])
      end
    end
  end
end
