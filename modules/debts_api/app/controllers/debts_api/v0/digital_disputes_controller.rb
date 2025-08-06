# frozen_string_literal: true

require 'debts_api/v0/digital_dispute_submission_service'

module DebtsApi
  module V0
    class DigitalDisputesController < ApplicationController
      service_tag 'debt-resolution'

      def create
        StatsD.increment("#{V0::DigitalDispute::STATS_KEY}.initiated")

        # 1. base64 files
        # 2. serilize user stuff
          # Needs:
            # user.uuid
            # user.ssn
            # user.participant_id
        user = {
          'uuid' => current_user.uuid,
          'ssn' => current_user.ssn,
          'participant_id' => current_user.participant_id
        }

        base_64_files = submission_params[:files].map do |file|
          {
            'fileName' => file.original_filename,
            'fileContents' => Base64.strict_encode64(file.read)
          }
        end

        digital_dispute = DebtsApi::V0::DigitalDispute.new(current_user, submission_params[:files])

        if digital_dispute.valid?
          StatsD.increment("#{V0::DigitalDispute::STATS_KEY}.success")
          render json: {
            message: result[:message],
            submission_id: result[:submission_id]
          }, status: :ok
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      private

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
