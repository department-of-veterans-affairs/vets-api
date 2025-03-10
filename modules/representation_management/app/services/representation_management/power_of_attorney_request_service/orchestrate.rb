# frozen_string_literal: true

module RepresentationManagement
  module PowerOfAttorneyRequestService
    class Orchestrate
      def initialize(data:, dependent:, form_data_object:, service_branch:, user:)
        @data = data
        @dependent = dependent
        @form_data_object = form_data_object
        @service_branch = service_branch
        @user = user

        @errors = []
      end

      def call
        if adapter_response[:errors].any?
          @errors << adapter_response[:errors]
          @errors.flatten!

          return { errors: @errors }
        end

        if create_response[:errors]&.any?
          @errors << create_response[:errors]
          @errors.flatten!

          return { errors: @errors }
        end

        enqueue_confirmation_email
        destroy_related_form

        {
          request: create_response[:request]
        }
      rescue => e
        @errors << e.message

        {
          errors: @errors
        }
      end

      private

      def adapter_response
        @adapter_response ||=
          AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Create::FormDataAdapter.new(
            data: @data,
            dependent: @dependent,
            service_branch: @service_branch
          ).call
      end

      def create_response
        @create_response ||=
          AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Create.new(
            claimant: @user.user_account,
            form_data: adapter_response[:data],
            poa_code: @data[:organization_id],
            registration_number: @data[:representative_id]
          ).call
      end

      def destroy_related_form
        InProgressForm.form_for_user('21-22', @user)&.destroy!
      end

      def enqueue_confirmation_email
        email_data = RepresentationManagement::PowerOfAttorneyRequestEmailData.new(form_data: @form_data_object)
        VANotify::EmailJob.perform_async(
          email_data.email_address,
          Settings.vanotify.services.va_gov.template_id.appoint_a_representative_digital_submit_confirmation_email,
          {
            'first_name' => email_data.first_name,
            'last_name' => email_data.last_name,
            'submit_date' => email_data.submit_date,
            'expiration_date' => email_data.expiration_date,
            'representative name' => email_data.representative_name
          }
        )
      end
    end
  end
end
