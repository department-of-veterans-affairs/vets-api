# frozen_string_literal: true

module RepresentationManagement
  module V0
    class NextStepsEmailController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate
      before_action :feature_enabled

      # Creates and enqueues an email with the provided "next steps" information. This action
      # validates the input parameters and, if valid, queues an email using the VANotify service.
      #
      # @return [JSON] Returns a success message if the email is enqueued, otherwise returns validation errors.
      #
      def create
        data = RepresentationManagement::NextStepsEmailData.new(next_steps_email_params)
        if data.valid?
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
          render json: { errors: data.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def feature_enabled
        routing_error unless Flipper.enabled?(:appoint_a_representative_enable_pdf)
      end

      # Strong parameters method for sanitizing input data for the next steps email.
      #
      # @return [ActionController::Parameters] Filtered parameters permitted for the next steps email.
      def next_steps_email_params
        params.require(:next_steps_email).permit(
          :email_address,
          :first_name,
          :form_name,
          :form_number,
          :entity_type,
          :entity_id
        )
      end
    end
  end
end
