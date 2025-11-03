# frozen_string_literal: true

module V0
  class MedicalCopaysController < ApplicationController
    service_tag 'debt-resolution'

    def index

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
