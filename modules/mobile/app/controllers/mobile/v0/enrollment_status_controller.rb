# frozen_string_literal: true

module Mobile
  module V0
    class EnrollmentStatusController < ApplicationController
      before_action :authorize_user
      before_action :validate_user_icn

      def show
        response = HealthCareApplication.enrollment_status(current_user.icn, true)
        response[:id] = current_user.uuid
        enrollment_status = Mobile::V0::EnrollmentStatus.new(response)
        json = Mobile::V0::EnrollmentStatusSerializer.new(enrollment_status)

        render(json:)
      end

      private

      def authorize_user
        raise_unauthorized('User is not loa3') unless current_user.loa3?
      end

      def validate_user_icn
        raise Common::Exceptions::RecordNotFound, current_user.uuid if current_user.icn.blank?
      end
    end
  end
end
