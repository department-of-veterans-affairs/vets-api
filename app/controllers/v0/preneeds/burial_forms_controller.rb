# frozen_string_literal: true
module V0
  module Preneeds
    class BurialFormsController < PreneedsController
      FORM = '40-10007'

      def new
      end

      def create
        forms = ::Preneeds::BurialForm.create_forms_array(burial_form_params)
        validate!(forms)

        resources = forms.map { |form| client.receive_pre_need_application(form.as_eoas) }
        render json: resources, each_serializer: ReceiveApplicationSerializer
      end

      private

      def burial_form_params
        params.require(:applications).map do |p|
          p.permit(
            :application_status, :has_attachments, :has_currently_buried, :sending_code,
            applicant: ::Preneeds::Applicant.permitted_params,
            claimant: ::Preneeds::Claimant.permitted_params,
            currently_buried_persons: [::Preneeds::CurrentlyBuriedPerson.permitted_params],
            veteran: ::Preneeds::Veteran.permitted_params
          )
        end
      end

      def validate!(forms)
        # TODO: Reinstate vets-json-schema once issue with currently buried is resolved
        # schema = VetsJsonSchema::SCHEMAS[FORM]
        schema = JSON.parse(File.read(Settings.preneeds.burial_form_schema))
        validation_errors = ::Preneeds::BurialForm.validate(schema, forms)

        if validation_errors.present?
          log_message_to_sentry(validation_errors.join(','), :error, {}, validation: 'preneeds')
          raise Common::Exceptions::SchemaValidationErrors, validation_errors
        end
      end
    end
  end
end
