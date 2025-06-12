# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'simple_forms_api_submission/metadata_validator'

module AccreditedRepresentativePortal
  module V0
    class RepresentativeFormUploadController < ApplicationController
      include AccreditedRepresentativePortal::V0::RepresentativeFormUploadConcern

      VALID_FORM_NUMBERS = %w[21-686c].freeze

      def submit
        authorize(claimant_representative, policy_class: RepresentativeFormUploadPolicy)
        Datadog::Tracing.active_trace&.set_tag('form_id', form_data[:formNumber])
        serialized = SavedClaimSerializer.new(saved_claim)
        render json: serialized.as_json.to_h.deep_transform_keys { |key| key.camelize(:lower) }
      end

      def upload_scanned_form
        authorize(nil, policy_class: RepresentativeFormUploadPolicy)
        handle_attachment_upload(PersistentAttachments::VAForm)
      end

      def upload_supporting_documents
        authorize(nil, policy_class: RepresentativeFormUploadPolicy)
        handle_attachment_upload(PersistentAttachments::VAFormDocumentation)
      end

      private

      def claimant_id
        @claimant_id ||= get_icn
      end

      def saved_claim
        AccreditedRepresentativePortal::SavedClaimService::Create.perform(
          type: AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim,
          attachment_guids: [params[:confirmationCode]], # TODO: multi form upload
          metadata: get_metadata,
          claimant_representative:
        )
      end

      def handle_attachment_upload(attachment_type)
        attachment = create_attachment(attachment_type)
        error = validate_attachment_upstream!(attachment)
        return render_error("Document validation failed: #{error.message}") if error

        error = validate_attachment!(attachment)
        return render_error("Document validation failed: #{error.message}") if error

        attachment.save
        render json: serialized(attachment)
      end

      def create_attachment(attachment_type)
        attachment_type.new(form_id: params[:form_id], file: params['file'])
      end

      def validate_attachment!(attachment)
        attachment.validate!
        nil
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error({
                             message: 'Attachment validation failed',
                             error: e.message,
                             form_id: attachment.form_id,
                             user_id: @current_user.uuid
                           })
        e
      end

      def validate_attachment_upstream!(attachment)
        lighthouse_service.valid_document?(document: attachment.to_pdf)
        nil
      rescue BenefitsIntake::Service::InvalidDocumentError => e
        Rails.logger.error({
                             message: 'Upstream document validation failed',
                             error: e.message,
                             user_id: @current_user.uuid
                           })
        e
      end

      def render_error(message)
        render json: { error: message }, status: :unprocessable_entity
      end

      def serialized(attachment)
        PersistentAttachmentSerializer.new(attachment).as_json.deep_transform_keys do |key|
          key.camelize(:lower)
        end
      end

      def lighthouse_service
        @lighthouse_service ||= BenefitsIntake::Service.new
      end

      def form
        @form ||= form_class.new(form_number: form_data[:formNumber])
      end

      def form_class
        unless VALID_FORM_NUMBERS.include? form_data[:formNumber]
          raise Common::Exceptions::BadRequest.new(detail: "Invalid form number #{form_data[:formNumber]}")
        end

        "SimpleFormsApi::VBA#{form_data[:formNumber].gsub(/-/, '').upcase}".constantize
      end

      def claimant_representative
        @claimant_representative ||= ClaimantRepresentative.find do |finder|
          finder.for_claimant(
            icn: claimant_id
          )

          finder.for_representative(
            icn: current_user.icn,
            email: current_user.email,
            all_emails: [current_user.email]
          )
        end
      end

      def get_icn
        mpi = MPI::Service.new.find_profile_by_attributes(ssn:, first_name:, last_name:, birth_date:)

        if mpi.profile&.icn
          mpi.profile.icn
        else
          raise Common::Exceptions::RecordNotFound, 'Could not lookup claimant with given information.'
        end
      end
    end
  end
end
