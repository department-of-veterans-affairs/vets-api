# frozen_string_literal: true
require 'sentry_logging'

module V0
  module Preneeds
    class BurialFormsController < PreneedsController
      include SentryLogging

      FORM = '40-10007'

      def create
        form = ::Preneeds::BurialForm.new(burial_form_params)
        validate!(form)

        resource = client.receive_pre_need_application(form.as_eoas)
        log_submission(resource)

        render json: resource, serializer: ReceiveApplicationSerializer
      end

      private

      def log_submission(resource)
        record = ::Preneeds::PreneedSubmission.create(
          tracking_number: resource.tracking_number,
          application_uuid: resource.application_uuid,
          return_description: resource.return_description,
          return_code: resource.return_code
        )

        unless record.persisted?
          errors = 'Preneeds submission record not persisted, missing required tracking, uuid, or return code'
          log_message_to_sentry(
            errors, :warning, { tracking_number: resource.tracking_number }, submission_logging: 'preneeds'
          )
        end
      end

      def burial_form_params
        params.require(:application).permit(
          :application_status, :has_attachments, :has_currently_buried, :sending_code,
          applicant: ::Preneeds::Applicant.permitted_params,
          claimant: ::Preneeds::Claimant.permitted_params,
          currently_buried_persons: [::Preneeds::CurrentlyBuriedPerson.permitted_params],
          veteran: ::Preneeds::Veteran.permitted_params
        )
      end

      def validate!(form)
        # Leave in for manual testing of new schemas before made available on Vets JSON Schema
        # schema = JSON.parse(File.read(Settings.preneeds.burial_form_schema))
        schema = VetsJsonSchema::SCHEMAS[FORM]
        validation_errors = ::Preneeds::BurialForm.validate(schema, form)

        if validation_errors.present?
          log_message_to_sentry(validation_errors.join(','), :error, {}, validation: 'preneeds')
          raise Common::Exceptions::SchemaValidationErrors, validation_errors
        end
      end
    end
  end
end
