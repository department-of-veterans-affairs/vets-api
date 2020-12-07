# frozen_string_literal: true

require_relative '../../../serializers/covid_vaccine/registration_submission_serializer'

module CovidVaccine
  module V0
    class RegistrationController < ApplicationController
      skip_before_action :authenticate, only: :create_unauthenticated
      # TODO: remove!!!
      skip_before_action :verify_authenticity_token

      def create
        svc = CovidVaccine::RegistrationService.new
        result = if @current_user.loa3?
                   svc.register_loa3_user(params[:registration], @current_user)
                 else
                   # Authenticated-but-LOA1 users are treated equivalently as unauthenticated
                   # users since we have to perform a speculative MVI lookup for them
                   svc.register(params[:registration], @current_user.account_uuid)
                 end
        render json: result, serializer: CovidVaccine::RegistrationSubmissionSerializer
      end

      def create_unauthenticated
        svc = CovidVaccine::RegistrationService.new
        result = svc.register(params[:registration])
        render json: result, serializer: CovidVaccine::RegistrationSubmissionSerializer
      end

      def show
        submission = CovidVaccine::RegistrationSubmission.for_user(current_user)
        render json: submission, serializer: CovidVaccine::RegistrationSubmissionSerializer
      end
    end
  end
end
