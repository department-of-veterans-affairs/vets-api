# frozen_string_literal: true

module V0
  class MedicalCopaysController < ApplicationController
    before_action { authorize :medical_copays, :access? }

    def index
      render json: vbs_service.get_copays
    end

    private

    def vbs_service
      MedicalCopays::VBS::Service.build(user: current_user)
    end
  end
end
