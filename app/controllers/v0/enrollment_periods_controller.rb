# frozen_string_literal: true

require 'veteran_enrollment_system/enrollment_periods/service'

module V0
  class EnrollmentPeriodsController < ApplicationController
    service_tag 'enrollment-periods'
    before_action { authorize :enrollment_periods, :access? }

    def index
      service = VeteranEnrollmentSystem::EnrollmentPeriods::Service.new
      periods = service.get_enrollment_periods(icn: @current_user.icn)
      render json: { enrollment_periods: periods }
    end
  end
end
