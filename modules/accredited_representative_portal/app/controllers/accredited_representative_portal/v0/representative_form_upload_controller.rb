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

      def submit
        service = SavedClaimService::Create

        saved_claim = service.perform(
          type: SavedClaim::BenefitsIntake::DependencyClaim,
          metadata:, attachment_guids:,
          claimant_representative:
        )

        render json: {
          confirmationNumber: saved_claim.confirmation_number,
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

      def authorize_attachment_upload
        authorize(nil, policy_class: RepresentativeFormUploadPolicy)
      end

      def authorize_submission
        authorize(claimant_representative, policy_class: RepresentativeFormUploadPolicy)
      end

      def handle_attachment_upload(model_klass, serializer_klass)
        service = SavedClaimService::Attach

        attachment = service.perform(
          model_klass, file: params[:file], form_id:
          SavedClaim::BenefitsIntake::DependencyClaim::FORM_ID
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

      def claimant_representative
        @claimant_representative ||=
          ClaimantRepresentative.find do |finder|
            finder.for_claimant(
              icn: claimant_icn
            )

            finder.for_representative(
              icn: current_user.icn,
              email: current_user.email,
              all_emails: current_user.all_emails
            )
          end
      end
    end
  end
end
