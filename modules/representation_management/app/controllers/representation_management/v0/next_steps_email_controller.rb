# frozen_string_literal: true

module RepresentationManagement
  module V0
    class NextStepsEmailController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate
      before_action :feature_enabled

      def create
        next_steps_email_data = RepresentationManagement::NextStepsEmailData.new(next_steps_email_params)
        if next_steps_email_data.invalid?
          render json: { errors: next_steps_email_data.errors.full_messages }, status: :unprocessable_entity and return
        else
          VANotify::EmailJob.perform_async(
            next_steps_email_data.email_address,
            Settings.vanotify.services.va_gov.template_id.appoint_a_representative_confirmation_email,
            {
              # The first_name is the only key here that has an underscore.
              # That is intentional.  All the keys here match the keys in the
              # template.
              'first_name' => next_steps_email_data.first_name,
              'form name' => next_steps_email_data.form_name,
              'form number' => next_steps_email_data.form_number,
              'representative type' => next_steps_email_data.representative_type_humanized,
              'representative name' => next_steps_email_data.representative_name,
              'representative address' => next_steps_email_data.representative_address
            }
          )
          render json: { message: 'Email enqueued' }, status: :ok
        end
      end

      private

      def feature_enabled
        routing_error unless Flipper.enabled?(:appoint_a_representative_enable_pdf)
      end

      def next_steps_email_params
        params.require(:next_steps_email).permit(
          :email_address,
          :first_name,
          :form_name,
          :form_number,
          :representative_type,
          :representative_name,
          :representative_address
        )
      end
    end
  end
end
