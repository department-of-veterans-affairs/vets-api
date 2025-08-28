# frozen_string_literal: true

require 'debts_api/v0/digital_dispute_submission_service'

module DebtsApi
  module V0
    class DigitalDisputesController < ApplicationController
      service_tag 'debt-resolution'

      def create
        StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.initiated")

        if Flipper.enabled?(:digital_dmc_dispute_service)
          submission = DebtsApi::V0::DigitalDisputeSubmission.new(
            user_uuid: current_user.uuid,
            user_account: current_user.user_account,
            state: :pending,
            metadata: submission_params[:metadata]
          )
          submission.files.attach(submission_params[:files])

          begin
            ApplicationRecord.transaction do
              submission.save!
              DebtsApi::V0::DigitalDisputeDmcService.new(current_user, submission).call!
            end

            StatsD.increment("#{KEY}.success")
            render json: { message: 'Submission received', submission_id: submission.id }, status: :ok

          rescue ActiveRecord::RecordInvalid => e
            StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.failure")
            render json: { success: false, error_type: 'validation_error', errors: e.record.errors.to_hash(true) },
                   status: :unprocessable_entity

          rescue DebtsApi::V0::DigitalDisputeDmcService::Error => e
            # DB rolled back because we were inside the transaction
            StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.failure")
            render json: { errors: [e.message] }, status: :bad_gateway
          end

        else
          result = process_submission
          if result[:success]
            StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.success")
            render json: { message: result[:message], submission_id: result[:submission_id] }, status: :ok
          else
            StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.failure")
            render json: { errors: result[:errors] }, status: :unprocessable_entity
          end
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
