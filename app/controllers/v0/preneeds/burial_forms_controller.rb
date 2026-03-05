# frozen_string_literal: true

require 'vets/shared_logging'

module V0
  module Preneeds
    class BurialFormsController < PreneedsController
      include Vets::SharedLogging

      FORM = '40-10007'
      API_KEY_PATH = 'Settings.vanotify.services.va_gov.api_key'

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
        render json: ReceiveApplicationSerializer.new(@resource)
      end

      def send_confirmation_email
        @name = confirmation_email_name
        email = @form.claimant.email
        template_id = Settings.vanotify.services.va_gov.template_id.preneeds_burial_form_email

        personalisation = confirmation_email_personalisation

        if Flipper.enabled?(:va_notify_v2_preneeds_burial_form_job)
          VANotify::V2::QueueEmailJob.enqueue(email, template_id, personalisation, API_KEY_PATH)
        else
          VANotify::EmailJob.perform_async(email, template_id, personalisation)
        end
      end

      private

      def confirmation_email_personalisation
        {
          'form_name' => 'Burial Pre-Need (Form 40-10007)',
          'first_name' => @form.applicant.name.first&.upcase.presence,
          'applicant_1_first_name_last_initial' => "#{@name.first} #{@name.last.first}",
          'confirmation_number' => @resource.application_uuid,
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y')
        }
      end

      def confirmation_email_name
        if @form.applicant.applicant_relationship_to_claimant == 'Self'
          @form.applicant.name
        else
          @form.claimant.name
        end
      end

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
          Sentry.set_tags(validation: 'preneeds')
          raise Common::Exceptions::SchemaValidationErrors, validation_errors
        end
      end
    end
  end
end
