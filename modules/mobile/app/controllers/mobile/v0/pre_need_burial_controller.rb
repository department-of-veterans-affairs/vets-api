# frozen_string_literal: true

require 'preneeds/service'

module Mobile
  module V0
    class PreNeedBurialController < ApplicationController
      FORM = '40-10007'

      def create
        form = ::Preneeds::BurialForm.new(burial_form_params)
        validate!(form)

        resource = client.receive_pre_need_application(form)

        create_local_preneed_submission(resource)

        render json: Mobile::V0::PreNeedBurialSerializer.new(resource)
      end

      private

      def create_local_preneed_submission(resource)
        ::Preneeds::PreneedSubmission.create!(
          tracking_number: resource.tracking_number,
          application_uuid: resource.application_uuid,
          return_description: resource.return_description,
          return_code: resource.return_code
        )
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
        schema = VetsJsonSchema::SCHEMAS[FORM]
        validation_errors = ::Preneeds::BurialForm.validate(schema, form.as_json)

        if validation_errors.present?
          Raven.tags_context(validation: 'preneeds')
          raise Common::Exceptions::SchemaValidationErrors, validation_errors
        end
      end

      def client
        @client ||= Preneeds::Service.new
      end
    end
  end
end
