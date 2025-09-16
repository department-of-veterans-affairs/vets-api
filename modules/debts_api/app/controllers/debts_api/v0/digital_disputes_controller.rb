# frozen_string_literal: true

require 'debts_api/v0/digital_dispute_submission_service'
require 'debts_api/v0/digital_dispute_dmc_service'

module DebtsApi
  module V0
    class DigitalDisputesController < ApplicationController
      service_tag 'debt-resolution'

      def create
        StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.initiated")
        Flipper.enabled?(:digital_dmc_dispute_service) ? create_via_dmc! : create_legacy!
      end

      private

      def create_via_dmc!
        submission = initialize_submission

        begin
          submission.save!
          DebtsApi::V0DigitalDisputeJob.perform_async(submission.id, current_user.participant_id)
          dmc_service(submission).call!

          StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.success")
          in_progress_form&.destroy
          render_success(submission)
        rescue ActiveRecord::RecordInvalid => e
          StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.failure")
          errors_hash = e.record.errors.to_hash
          Rails.logger.error(
            "DigitalDisputeController#create validation error: #{errors_hash.values.flatten.to_sentence}"
          )
          render json: { errors: errors_hash }, status: :unprocessable_entity
        rescue => e
          submission.clean_up_failure

          Rails.logger.error("DigitalDisputeController#create error: #{e.message} #{e.backtrace&.take(12)&.join("\n")}")

          StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.failure")
          render json: { errors: { base: [e.message] } }, status: :unprocessable_entity
        end
      end

      def in_progress_form
        InProgressForm.form_for_user('DISPUTE-DEBT', current_user)
      end

      def create_legacy!
        result = process_submission
        if result[:success]
          StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.success")
          render json: { message: result[:message], submission_id: result[:submission_id] }, status: :ok
        else
          StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.failure")
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      def initialize_submission
        DebtsApi::V0::DigitalDisputeSubmission.new(
          user_uuid: current_user.uuid,
          user_account: current_user.user_account,
          state: :pending,
          metadata: submission_params[:metadata]
        ).tap { |s| s.files.attach(submission_params[:files]) }
      end

      def dmc_service(submission)
        DebtsApi::V0::DigitalDisputeDmcService.new(current_user, submission)
      end

      def render_success(submission)
        render json: { message: 'Submission received', submission_id: submission.id }, status: :ok
      end

      def render_validation_error(record)
        render json: { success: false, error_type: 'validation_error', errors: record.errors.to_hash(true) },
               status: :unprocessable_entity
      end

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
