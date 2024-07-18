# frozen_string_literal: true

module Mobile
  module V0
    class EnrollmentStatusController < ApplicationController
      def show
        raise Common::Exceptions::Unauthorized unless current_user.loa3?

        raise Common::Exceptions::RecordNotFound, 'User ICN not found' if current_user.icn.blank?

        json = HealthCareApplication.enrollment_status(current_user.icn, true)
        enrollment_status = Mobile::V0::EnrollmentStatus.new(json)
        serialized = Mobile::V0::EnrollmentStatusSerializer.new(enrollment_status)

        render(json: serialized)
      end
    end
  end
end