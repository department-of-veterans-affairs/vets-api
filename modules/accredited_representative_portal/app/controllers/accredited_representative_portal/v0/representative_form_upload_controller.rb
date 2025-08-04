# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'simple_forms_api_submission/metadata_validator'

module AccreditedRepresentativePortal
  module V0
    class RepresentativeFormUploadController < ApplicationController
      include AccreditedRepresentativePortal::V0::RepresentativeFormUploadConcern

      before_action :authorize_submission, only: :submit
      before_action :authorize_attachment_upload, only: %i[
        upload_scanned_form
        upload_supporting_documents
      ]
      before_action :deny_access_unless_686c_enabled, only: %i[
        submit
        upload_scanned_form
        upload_supporting_documents
      ]

      def submit
        service = SavedClaimService::Create

        saved_claim = service.perform(
          type: form_class,
          metadata:, attachment_guids:,
          claimant_representative:
        )

        render json: {
          confirmationNumber:
            saved_claim.latest_submission_attempt.benefits_intake_uuid,
          status: '200'
        }
      rescue service::RecordInvalidError => e
        raise Common::Exceptions::ValidationErrors, e.record
      rescue service::WrongAttachmentsError => e
        raise Common::Exceptions::UnprocessableEntity,
              detail: e.message

      ##
      # Once we have a uniform strategy for handling errors in our controllers,
      # we may be comfortable allowing parent code to handle these generic
      # errors for us implicitly.
      #
      rescue service::UnknownError => e
        # Is there any particular reason to prefer `e.cause` over `e`?
        raise Common::Exceptions::InternalServerError, e.cause
      end

      def upload_scanned_form
        handle_attachment_upload(
          PersistentAttachments::VAForm,
          PersistentAttachmentVAFormSerializer
        )
      end

      def upload_supporting_documents
        handle_attachment_upload(
          PersistentAttachments::VAFormDocumentation,
          PersistentAttachmentSerializer
        )
      end

      private

      def form_id
        if params[:form_id].present?
          params[:form_id].gsub(/-UPLOAD/, '')
        else
          submit_params[:formData][:formNumber]
        end
      end

      def authorize_attachment_upload
        authorize(nil, policy_class: RepresentativeFormUploadPolicy)
      end

      def authorize_submission
        claimant_icn.present? or
          raise Common::Exceptions::RecordNotFound, <<~MSG.squish
            Could not lookup claimant with given information.
          MSG

        authorize(
          claimant_representative,
          policy_class: RepresentativeFormUploadPolicy
        )
      end

      def handle_attachment_upload(model_klass, serializer_klass)
        service = SavedClaimService::Attach

        attachment = service.perform(
          model_klass, file: params[:file], form_id: form_class::PROPER_FORM_ID
        )

        json = serializer_klass.new(attachment).as_json
        json = json.deep_transform_keys do |key|
          key.camelize(:lower)
        end

        render json:
      rescue service::RecordInvalidError => e
        raise Common::Exceptions::ValidationErrors, e.record
      rescue service::UpstreamInvalidError => e
        raise Common::Exceptions::UpstreamUnprocessableEntity,
              detail: e.message

      ##
      # Once we have a uniform strategy for handling errors in our controllers,
      # we may be comfortable allowing parent code to handle these generic
      # errors for us implicitly.
      #
      rescue service::UnknownError => e
        # Is there any particular reason to prefer `e.cause` over `e`?
        raise Common::Exceptions::InternalServerError, e.cause
      end

      def form_class
        SavedClaim::BenefitsIntake.form_class_from_proper_form_id(form_id)
      end
    end
  end
end
