# frozen_string_literal: true
module V0
  module Preneeds
    class ApplicationFormsController < PreneedsController
      def new
      end

      def create
        application_form = ::Preneeds::ApplicationForm.new(application_form_params)
        validate!(application_form)

        resource = client.receive_pre_need_application(application_form.message)
        render json: resource, serializer: ReceiveApplicationSerializer
      end

      private

      def application_form_params
        params.require(:pre_need_request)
              .permit(
                :application_status, :has_attachments, :has_currently_buried, :sending_code,
                applicant: ::Preneeds::Applicant.permitted_params,
                claimant: ::Preneeds::Claimant.permitted_params,
                currently_buried_persons: [::Preneeds::CurrentlyBuriedPerson.permitted_params],
                veteran: ::Preneeds::Veteran.permitted_params
              )
      end

      def validate!(form)
        # TODO: replace this schema once VetsJsonSchema preneeds is merged.
        schema = JSON.parse(File.read(Settings.preneeds.application_form_schema))
        validation_errors = form.validate(schema, :pre_need_request)

        if validation_errors.present?
          log_message_to_sentry(validation_errors.join(','), :error, {}, validation: 'preneeds')
          raise Common::Exceptions::SchemaValidationErrors, validation_errors
        end
      end
    end
  end
end
