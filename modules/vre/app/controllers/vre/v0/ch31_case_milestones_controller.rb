# frozen_string_literal: true

module VRE
  module V0
    class Ch31CaseMilestonesController < ApplicationController
      service_tag 'vre-application'

      def create
        response = case_milestones_service.update_milestones(milestone_params)
        render json: VRE::Ch31CaseMilestonesSerializer.new(response)
      rescue Common::Exceptions::ParameterMissing => e
        render json: { errors: [{ detail: e.message }] }, status: :bad_request
      rescue Common::Exceptions::Forbidden => e
        render json: { errors: [{ detail: e.message }] }, status: :forbidden
      rescue Common::Exceptions::BackendServiceException => e
        status = e.response_values[:status] || e.status_code || :internal_server_error
        # Extract error message from original body if available
        error_message = if e.original_body && e.original_body['errorMessageList']
                          e.original_body['errorMessageList'].first
                        else
                          e.message
                        end
        render json: { errors: [{ detail: error_message }] }, status:
      end

      private

      def case_milestones_service
        VRE::Ch31CaseMilestones::Service.new(@current_user&.icn)
      end

      def milestone_params
        params.permit(
          milestones: %i[milestoneType isMilestoneCompleted milestoneCompletionDate milestoneSubmissionUser postpone]
        )
      end
    end
  end
end
