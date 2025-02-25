# frozen_string_literal: true

module RepresentationManagement
  module PowerOfAttorneyRequestService
    class Orchestrate
      def initialize(data:, dependent:, service_branch:, user:)
        @data = data
        @dependent = dependent
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
    end
  end
end
