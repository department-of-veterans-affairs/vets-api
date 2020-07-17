# frozen_string_literal: true

module V0
  # Application for the Program of Comprehensive Assistance for Family Caregivers (Form 10-10CG)
  class CaregiversAssistanceClaimsController < ApplicationController
    skip_before_action(:authenticate)

    rescue_from ::Form1010cg::Service::InvalidVeteranStatus, with: :backend_service_outage

    def create
      return service_unavailable unless Flipper.enabled?(:allow_online_10_10cg_submissions)

      claim = SavedClaim::CaregiversAssistanceClaim.new(form: form_submission)

      if claim.valid?
        submission = ::Form1010cg::Service.new(claim).process_claim!
        render json: submission, serializer: ::Form1010cg::SubmissionSerializer
      else
        raise(Common::Exceptions::ValidationErrors, claim)
      end
    end

    private

    def form_submission
      params.require(:caregivers_assistance_claim).require(:form)
    end

    def service_unavailable
      render nothing: true, status: :service_unavailable, as: :json
    end

    def backend_service_outage
      render_errors Common::Exceptions::ServiceOutage.new(nil, detail: 'Backend Service Outage')
    end
  end
end
