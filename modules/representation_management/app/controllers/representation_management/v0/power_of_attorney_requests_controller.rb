# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PowerOfAttorneyRequestsController < RepresentationManagement::V0::PowerOfAttorneyRequestBaseController
      service_tag 'representation-management'
      before_action :feature_enabled

      DOES_NOT_ACCEPT_DIGITAL_REQUESTS = 'Accredited organization does not accept digital Power of Attorney Requests'
      MISSING_ICN = 'User is missing an ICN value'
      MISSING_PARTICIPANT_ID = 'User is missing a Corp Participant ID value'
      DEPENDENT_SUBMITTER = 'User must submit as the Veteran for digital Power of Attorney Requests'

      def create
        validate_request_data

        if @errors.any?
          render json: { errors: @errors }, status: :unprocessable_entity
        elsif orchestrate_response[:errors]&.any?
          render json: { errors: orchestrate_response[:errors] }, status: :unprocessable_entity
        else
          render json: RepresentationManagement::PowerOfAttorneyRequestSerializer.new(orchestrate_response[:request]),
                 status: :created
        end
      end

      private

      def feature_enabled
        routing_error unless Flipper.enabled?(:appoint_a_representative_enable_v2_features)
      end

      def form_params
        params.require(:power_of_attorney_request).permit(params_permitted)
      end

      def flatten_form_params
        @flatten_form_params ||=
          {
            representative_id: form_params[:representative][:id],
            organization_id: form_params[:representative][:organization_id],
            record_consent: [true, 'true'].include?(form_params[:record_consent]),
            consent_limits:,
            consent_address_change: [true, 'true'].include?(form_params[:consent_address_change])
          }.merge(flatten_veteran_params(form_params))
          .merge(flatten_claimant_params(form_params))
      end

      def dependent
        form_params[:claimant].present?
      end

      def service_branch
        form_params.dig(:veteran, :service_branch)
      end

      def consent_limits
        if form_params[:consent_limits].all?(&:blank?)
          []
        else
          form_params[:consent_limits]
        end
      end

      def form
        @form ||= RepresentationManagement::Form2122Data.new(flatten_form_params)
      end

      def orchestrate_response
        @orchestrate_response ||=
          RepresentationManagement::PowerOfAttorneyRequestService::Orchestrate.new(
            data: flatten_form_params,
            dependent:,
            form_data_object: form,
            service_branch:,
            user: current_user
          ).call
      end

      def validate_request_data
        @errors = []

        validate_user_identifiers
        validate_form
        validate_organization_accepts_digital_requests
        validate_user_is_veteran_submitter
      end

      def validate_form
        unless form.valid?
          @errors << form.errors.full_messages
          @errors.flatten!
        end
      end

      def validate_organization_accepts_digital_requests
        @errors << DOES_NOT_ACCEPT_DIGITAL_REQUESTS unless form.organization&.can_accept_digital_poa_requests
      end

      def validate_user_identifiers
        @errors << MISSING_ICN if current_user.icn.blank?

        @errors << MISSING_PARTICIPANT_ID if current_user.participant_id.blank?
      end

      def validate_user_is_veteran_submitter
        @errors << DEPENDENT_SUBMITTER if dependent
      end
    end
  end
end
