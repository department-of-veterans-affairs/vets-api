# frozen_string_literal: true

require_relative '../../../serializers/covid_vaccine/v0/registration_submission_serializer'
require_relative '../../../serializers/covid_vaccine/v0/registration_summary_serializer'

module CovidVaccine
  module V0
    class RegistrationController < CovidVaccine::ApplicationController
      include IgnoreNotFound

      before_action :validate_raw_form_data, only: :create
      skip_before_action :verify_authenticity_token, only: :opt_out

      def create
        raw_form_data = params[:registration].merge(attributes_from_user)
        account_id = @current_user&.account_uuid
        record = CovidVaccine::V0::RegistrationSubmission.create!({ account_id:,
                                                                    raw_form_data: })

        CovidVaccine::SubmissionJob.perform_async(record.id, user_type)
        render json: record, serializer: CovidVaccine::V0::RegistrationSummarySerializer, status: :created
      end

      def show
        submission = CovidVaccine::V0::RegistrationSubmission.for_user(current_user).last
        raise Common::Exceptions::RecordNotFound, nil if submission.blank?

        render json: submission, serializer: CovidVaccine::V0::RegistrationSubmissionSerializer
      end

      def opt_out
        CovidVaccine::V0::VetextService.new.put_email_opt_out(sid)
        head :no_content
      end

      def opt_in
        CovidVaccine::V0::VetextService.new.put_email_opt_in(sid)
        head :no_content
      end

      private

      def sid
        params.require(:sid)
      end

      def validate_raw_form_data
        form_data = CovidVaccine::V0::RawFormData.new(params[:registration] || {})
        raise Common::Exceptions::ValidationErrors, form_data unless form_data.valid?
      end

      # Merge in these attributes from the authenticated user, since
      # we won't have access to that object from the submission worker
      def attributes_from_user
        return {} unless @current_user&.loa3?

        {
          'first_name' => @current_user.first_name,
          'last_name' => @current_user.last_name,
          'birth_date' => @current_user.birth_date,
          'ssn' => @current_user.ssn,
          'icn' => @current_user.icn
        }
      end

      def user_type
        return 'unauthenticated' if @current_user.blank?
        return 'loa3' if @current_user&.loa3?

        'loa1'
      end
    end
  end
end
