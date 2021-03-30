# frozen_string_literal: true

module V0
  class DependentsVerificationsController < ApplicationController
    def index
      dependents = dependency_verification_service.read_diaries

      render json: dependents, serializer: DependentsVerificationsSerializer
    end

    def create
      dependency_verification_service.update_diaries if params[:update_diaries] == 'true'

      head :ok
    end

    private

    def dependency_verification_service
      @dependent_service ||= BGS::DependencyVerificationService.new(current_user)
    end
  end
end
