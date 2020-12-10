# frozen_string_literal: true

require_relative '../../../serializers/covid_vaccine/v0/registration_submission_serializer'

module CovidVaccine
  module V0
    class RegistrationController < CovidVaccine::ApplicationController
      def create
        svc = CovidVaccine::V0::RegistrationService.new
        result = if @current_user
                   if @current_user.loa3?
                     svc.register_loa3_user(params[:registration], @current_user)
                   else
                     # Authenticated-but-LOA1 users are treated equivalently as unauthenticated
                     # users since we have to perform a speculative MVI lookup for them
                     svc.register(params[:registration], @current_user.account_uuid)
                   end
                 else
                   svc.register(params[:registration])
                 end
        render json: result, serializer: CovidVaccine::V0::RegistrationSubmissionSerializer
      end

      def show
        submission = CovidVaccine::V0::RegistrationSubmission.for_user(current_user).last
        raise Common::Exceptions::RecordNotFound, nil if submission.blank?

        render json: submission, serializer: CovidVaccine::V0::RegistrationSubmissionSerializer
      end
    end
  end
end
