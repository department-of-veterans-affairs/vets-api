# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PowerOfAttorneySubmissionsController < RepresentationManagement::V0::PowerOfAttorneyRequestBaseController
      service_tag 'representation-management'
      before_action :feature_enabled

      # Creates and enqueues an email with the provided "next steps" information. This action
      # validates the input parameters and, if valid, queues an email using the VANotify service.
      #
      # @return [JSON] Returns a success message if the email is enqueued, otherwise returns validation errors.
      #
      def create
        form = RepresentationManagement::Form2122Data.new(flatten_form_params)

        if params[:veteran][:service_number].present?
          render json: { errors: ['render_error_state_for_failed_submission'] }, status: :unprocessable_entity
        elsif form.valid?
          VANotify::EmailJob.perform_async(
            data.email_address,
            Settings.vanotify.services.va_gov.template_id.appoint_a_representative_confirmation_email,
            {
              # The first_name is the only key here that has an underscore.
              # That is intentional.  All the keys here match the keys in the
              # template.
              'first_name' => data.first_name,
              'form name' => data.form_name,
              'form number' => data.form_number,
              'representative type' => data.entity_display_type,
              'representative name' => data.entity_name,
              'representative address' => data.entity_address
            }
          )
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
        params.require(:power_of_attorney_submission).permit(params_permitted)
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
