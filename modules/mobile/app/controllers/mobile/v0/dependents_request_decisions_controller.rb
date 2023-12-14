# frozen_string_literal: true

module Mobile
  module V0
    class DependentsRequestDecisionsController < ApplicationController
      def index
        resource = dependency_verification_service.read_diaries

        render json: Mobile::V0::DependentsRequestDecisionsSerializer.new(@current_user.uuid, resource)
      end

      private

      def dependency_verification_service
        BGS::DependencyVerificationService.new(@current_user)
      end
    end
  end
end
