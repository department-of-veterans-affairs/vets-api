# frozen_string_literal: true

require 'debts_api/v0/digital_dispute_submission_service'

module DebtsApi
  module V0
    class DigitalDisputesController < ApplicationController
      service_tag 'debt-resolution'

      def create
        StatsD.increment("#{V0::DigitalDisputeSubmission::STATS_KEY}.initiated")

        if Flipper.enabled?(:financial_management_digital_dispute_async)
          execute_async_job
          render json: { message: 'Digital dispute submission received successfully' }, status: :ok
        else
          result = process_submission

          if result[:success]
            StatsD.increment("#{V0::DigitalDisputeSubmission::STATS_KEY}.success")
            render json: {
              message: result[:message],
              submission_id: result[:submission_id]
            }, status: :ok
          else
            render json: { errors: result[:errors] }, status: :unprocessable_entity
          end
        end
      end

      private

      def execute_async_job
        user_params = {
          'uuid' => current_user.uuid,
          'ssn' => current_user.ssn,
          'participant_id' => current_user.participant_id
        }

        metadata = parse_metadata(submission_params[:metadata])

        # base64 encoding so job can handle files
        base_64_files = submission_params[:files].map do |file|
          {
            'fileName' => file.original_filename,
            'fileContents' => Base64.strict_encode64(file.read)
          }
        end
        DebtsApi::V0::DigitalDisputeJob.perform_async(
          user_params, metadata, base_64_files
        )
      end

      def process_submission
        metadata = parse_metadata(submission_params[:metadata])

        service = DebtsApi::V0::DigitalDisputeSubmissionService.new(
          current_user,
          submission_params[:files],
          metadata
        )
        service.call
      end

      def parse_metadata(metadata_param)
        return nil if metadata_param.blank?
        return metadata_param if metadata_param.is_a?(Hash)

        JSON.parse(metadata_param, symbolize_names: true)
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
