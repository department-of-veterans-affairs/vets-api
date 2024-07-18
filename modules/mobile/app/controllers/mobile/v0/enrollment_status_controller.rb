# frozen_string_literal: true

module Mobile
  module V0
    class EnrollmentStatusController < ApplicationController
      def show
        # raise unauthorized if loa is not 3

        raise Common::Exceptions::RecordNotFound if current_user.icn.blank?

        json = HealthCareApplication.enrollment_status(current_user.icn, true)
        enrollment_status = Mobile::V0::EnrollmentStatus.new(json)
        serialized = Mobile::V0::EnrollmentStatusSerializer.new(enrollment_status)

        render(json: serialized)
      end
    end
  end
end