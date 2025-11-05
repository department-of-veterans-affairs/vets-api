# frozen_string_literal: true

module V0
  class MedicalCopaysHistoryController < ApplicationController
    service_tag 'debt-resolution'

    def index
      copays = medical_copay_service.list
      render json: Lighthouse::HealthcareCostAndCoverage.new(copays)
    end

    def count
      render json: { count: medical_copay_service.count }
    end

    private

    def medical_copay_service
      MedicalCopays::Lighthouse::Service.new(current_user.icn)
    end
  end
end
