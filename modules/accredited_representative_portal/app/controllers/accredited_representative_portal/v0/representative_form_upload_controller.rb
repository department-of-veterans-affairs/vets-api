# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'simple_forms_api_submission/metadata_validator'

module AccreditedRepresentativePortal
  module V0
    class RepresentativeFormUploadController < ApplicationController
      include AccreditedRepresentativePortal::V0::RepresentativeFormUploadConcern

      VALID_FORM_NUMBERS = %w[21-686c].freeze

      before_action :authorize_attachment_upload, only: %i[
        upload_scanned_form
        upload_supporting_documents
      ]

      def submit
        authorize(get_icn, policy_class: RepresentativeFormUploadPolicy)
        Datadog::Tracing.active_trace&.set_tag('form_id', form_data[:formNumber])
        status, confirmation_number = upload_response
        render json: { status:, confirmationNumber: confirmation_number }
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

      def handle_attachment_upload(model_klass, serializer_klass)
        attachment =
          SavedClaimService::Attach.perform(
            model_klass, file: params[:file], form_id:
              SavedClaim::BenefitsIntake::DependencyClaim::FORM_ID
          )

        json = serializer_klass.new(attachment).as_json
        json = json.deep_transform_keys do |key|
          key.camelize(:lower)
        end

        render json:
      rescue SavedClaimService::Attach::RecordInvalidError => e
        raise Common::Exceptions::ValidationErrors, e.record
      rescue SavedClaimService::Attach::UpstreamInvalidError => e
        raise Common::Exceptions::UpstreamUnprocessableEntity,
              detail: e.message

      ##
      # Once we have a uniform strategy for handling errors in our controllers,
      # we may be comfortable allowing parent code to handle these generic
      # errors for us implicitly.
      #
      rescue SavedClaimService::Attach::UnknownError => e
        # Is there any particular reason to prefer `e.cause` over `e`?
        raise Common::Exceptions::InternalServerError, e.cause
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

      def upload_response
        file_path = find_attachment_path(form_params[:confirmationCode])
        stamper = SimpleFormsApi::PdfStamper.new(
          form:,
          stamped_template_path: file_path,
          current_loa: @current_user.loa[:current],
          timestamp: Time.current
        )
        stamper.stamp_pdf
        raw_metadata = validated_metadata
        metadata = SimpleFormsApiSubmission::MetadataValidator.validate(raw_metadata)
        status, confirmation_number = upload_pdf(file_path, metadata)
        file_size = File.size(file_path).to_f / (2**20)

        Rails.logger.info(
          'Accredited Rep Form Upload - scanned form uploaded',
          { form_number: form_data[:formNumber], status:, confirmation_number:, file_size: }
        )
        [status, confirmation_number]
      end

      def find_attachment_path(confirmation_code)
        PersistentAttachment.find_by(guid: confirmation_code).to_pdf.to_s
      end

      def upload_pdf(file_path, metadata)
        location, uuid = prepare_for_upload
        log_upload_details(location, uuid)
        response = perform_pdf_upload(location, file_path, metadata)
        [response.status, uuid]
      end

      def prepare_for_upload
        location, uuid = lighthouse_service.request_upload
        create_form_submission_attempt(uuid)

        [location, uuid]
      end

      def create_form_submission_attempt(uuid)
        FormSubmissionAttempt.transaction do
          form_submission = create_form_submission
          FormSubmissionAttempt.create(form_submission:, benefits_intake_uuid: uuid)
        end
      end

      def create_form_submission
        FormSubmission.create(
          form_type: form_data[:formNumber],
          form_data: form_data.to_json,
          user_account: @current_user&.user_account
        )
      end

      def log_upload_details(location, uuid)
        Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
        Rails.logger.info('Accredited Rep Form Upload - preparing to upload scanned PDF to benefits intake',
                          { location:, uuid: })
      end

      def perform_pdf_upload(location, file_path, metadata)
        lighthouse_service.perform_upload(
          metadata: metadata.to_json,
          document: file_path,
          upload_url: location
        )
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
