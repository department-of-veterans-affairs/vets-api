# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PowerOfAttorneyRequestsController < RepresentationManagement::V0::PowerOfAttorneyRequestBaseController
      service_tag 'representation-management'
      before_action :feature_enabled

      def create
        form = RepresentationManagement::Form2122Data.new(flatten_form_params)

        if flatten_form_params[:veteran_service_number].present?
          render json: { errors: ['render_error_state_for_failed_submission'] }, status: :unprocessable_entity
        elsif form.valid?
          render json: { message: 'Email enqueued' }, status: :ok
        else
          render json: { errors: form.errors.full_messages }, status: :unprocessable_entity
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
        {
          representative_id: form_params[:representative][:id],
          organization_id: form_params[:representative][:organization_id],
          record_consent: form_params[:record_consent],
          consent_limits: form_params[:consent_limits],
          consent_address_change: form_params[:consent_address_change]
        }.merge(flatten_veteran_params(form_params))
          .merge(flatten_claimant_params(form_params))
      end
    end
  end
end
