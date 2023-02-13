# frozen_string_literal: true

module V0
  module Preneeds
    class BurialFormsController < PreneedsController
      include SentryLogging

      FORM = '40-10007'

      def create
        @form = ::Preneeds::BurialForm.new(burial_form_params)
        validate!(Common::HashHelpers.deep_transform_parameters!(burial_form_params) { |k| k.camelize(:lower) })

        @resource = client.receive_pre_need_application(@form)
        ::Preneeds::PreneedSubmission.create!(
          tracking_number: @resource.tracking_number,
          application_uuid: @resource.application_uuid,
          return_description: @resource.return_description,
          return_code: @resource.return_code
        )

        send_confirmation_email

        clear_saved_form(FORM)
        render json: @resource, serializer: ReceiveApplicationSerializer
      end

      def send_confirmation_email
        email = @form.claimant.email
        claimant = @form.applicant.name.first
        first_name = @form.applicant.name.first
        last_initial = @form.applicant.name.last.first

        if @form.applicant.applicant_relationship_to_claimant != 'Self'
          first_name = @form.claimant.name.first
          last_initial = @form.claimant.name.last.first
        end

        VANotify::EmailJob.perform_async(
          email,
          Settings.vanotify.services.va_gov.template_id.preneeds_burial_form_email,
          {
            'form_name' => 'Burial Pre-Need (Form 40-10007)',
            'first_name' => claimant&.upcase.presence,
            'applicant_1_first_name_last_initial' => "#{first_name} #{last_initial}",
            'confirmation_number' => @resource.application_uuid,
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y')
          }
        )
      end

      private

      def burial_form_params
        params.require(:application).permit(
          :application_status, :has_currently_buried, :sending_code,
          preneed_attachments: ::Preneeds::PreneedAttachmentHash.permitted_params,
          applicant: ::Preneeds::Applicant.permitted_params,
          claimant: ::Preneeds::Claimant.permitted_params,
          currently_buried_persons: ::Preneeds::CurrentlyBuriedPerson.permitted_params,
          veteran: ::Preneeds::Veteran.permitted_params
        )
      end

      def validate!(form)
        # Leave in for manual testing of new schemas before made available on Vets JSON Schema
        # schema = JSON.parse(File.read(Settings.preneeds.burial_form_schema))
        schema = VetsJsonSchema::SCHEMAS[FORM]
        validation_errors = ::Preneeds::BurialForm.validate(schema, form)

        if validation_errors.present?
          Raven.tags_context(validation: 'preneeds')
          raise Common::Exceptions::SchemaValidationErrors, validation_errors
        end
      end
    end
  end
end
