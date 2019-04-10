# frozen_string_literal: true

require 'sentry_logging'
require 'preneeds/logged_service'

module V0
  module Preneeds
    class BurialFormsController < PreneedsController
      include SentryLogging

      def create
        @form = ::Preneeds::BurialForm.new(burial_form_params)
        validate!

        resource = client.receive_pre_need_application(@form)
        ::Preneeds::PreneedSubmission.create!(
          tracking_number: resource.tracking_number,
          application_uuid: resource.application_uuid,
          return_description: resource.return_description,
          return_code: resource.return_code
        )

        render json: resource, serializer: ReceiveApplicationSerializer
      end

      private

      def client
        @client ||= ::Preneeds::LoggedService.new
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

      def validate!
        validation_errors = @form.validate

        if validation_errors.present?
          Raven.tags_context(validation: 'preneeds')
          raise Common::Exceptions::SchemaValidationErrors, validation_errors
        end
      end
    end
  end
end
