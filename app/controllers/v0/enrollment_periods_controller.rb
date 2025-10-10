# frozen_string_literal: true

module V0
  class EnrollmentPeriodsController < ApplicationController
    service_tag 'enrollment-periods'
    before_action { authorize :enrollment_periods, :access? }

    def index
      service = VeteranEnrollmentSystem::EnrollmentPeriods::Service.new
      periods = service.get_enrollment_periods(@current_user.icn)
      render json: { enrollment_periods: periods }
    end
  end
end
