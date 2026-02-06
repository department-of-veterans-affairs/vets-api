# frozen_string_literal: true

module VRE
  module V0
    class Ch31CaseMilestonesController < ApplicationController
      service_tag 'vre-application'

      def create
        response = case_milestones_service.update_milestones(milestone_params)
        render json: VRE::Ch31CaseMilestonesSerializer.new(response)
      end

      private

      def case_milestones_service
        VRE::Ch31CaseMilestones::Service.new(@current_user&.icn)
      end

      def milestone_params
        params.permit(milestones: [:milestoneType, :isMilestoneCompleted, :milestoneCompletionDate, :milestoneSubmissionUser])
      end
    end
  end
end
