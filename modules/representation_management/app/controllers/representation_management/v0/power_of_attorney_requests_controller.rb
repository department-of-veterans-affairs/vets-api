# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PowerOfAttorneyRequestsController < RepresentationManagement::V0::PowerOfAttorneyRequestBaseController
      service_tag 'representation-management'
      before_action :feature_enabled

      def create
        if !form.valid?
          render json: { errors: form.errors.full_messages }, status: :unprocessable_entity
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
        @form ||= RepresentationManagement::Form2122DigitalSubmission.new(user: current_user, dependent:,
                                                                          **flatten_form_params)
      end

      def orchestrate_response
        @orchestrate_response ||=
          RepresentationManagement::PowerOfAttorneyRequestService::Orchestrate.new(
            data: flatten_form_params.merge(consent_limits: form.normalized_limitations_of_consent),
            dependent:,
            service_branch:,
            user: current_user
          ).call
      end
    end
  end
end
