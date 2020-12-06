# frozen_string_literal: true

module CovidVaccine
  module V0
    class RegistrationController < ApplicationController
      skip_before_action :authenticate, only: :create_unauthenticated

      def create
          
      end

      def create_unauthenticated

      end

      def show
        submission = CovidVaccine::RegistrationSubmission.for_user(current_user)
        render json: submission, serializer: CovidVaccine::RegistrationSubmissionSerializer
      end

    end
  end
end

