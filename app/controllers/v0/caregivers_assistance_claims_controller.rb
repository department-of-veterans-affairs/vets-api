# frozen_string_literal: true

module V0
  # Application for the Program of Comprehensive Assistance for Family Caregivers (Form 10-10CG)
  class CaregiversAssistanceClaimsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      return service_unavailable unless Flipper.enabled?(:allow_online_10_10cg_submissions)

      submission = service.submit_claim!(form: form_submission)
      render json: submission, serializer: ::Form1010cg::SubmissionSerializer
    end

    private

    def service
      @service ||= ::Form1010cg::Service.new
    end

    def form_submission
      params.require(:caregivers_assistance_claim).require(:form)
    end

    def service_unavailable
      render status: :service_unavailable
    end
  end
end
