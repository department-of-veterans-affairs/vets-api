# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'simple_forms_api_submission/metadata_validator'

module AccreditedRepresentativePortal
  module V0
    class RepresentativeFormUploadController < ApplicationController
      include AccreditedRepresentativePortal::V0::RepresentativeFormUploadConcern
      skip_after_action :verify_pundit_authorization, only: :upload_scanned_form
      before_action(only: :submit) do
        authorize(get_icn, policy_class: RepresentativeFormUploadPolicy)
      end

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', form_data[:formNumber])
        status, confirmation_number = upload_response
        send_confirmation_email(params, confirmation_number) if status == 200
        render json: { status:, confirmation_number: }
      end

      def upload_scanned_form
        attachment = PersistentAttachments::VAForm.new
        attachment.form_id = params['form_id']
        attachment.file = params['file']
        raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

        attachment.save
        serialized = PersistentAttachmentVAFormSerializer.new(attachment).as_json.deep_transform_keys do |key|
          key.camelize(:lower)
        end
        render json: serialized
      end

      private

      def lighthouse_service
        @lighthouse_service ||= BenefitsIntake::Service.new
      end

      def upload_response
        file_path = find_attachment_path(params[:confirmationCode])
        stamper = SimpleFormsApi::PdfStamper.new(
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

      def send_confirmation_email(_params, confirmation_number)
        new_form_data = create_new_form_data
        config = {
          form_number: form_data[:formNumber],
          form_data: new_form_data,
          date_submitted: Time.zone.today.strftime('%B %d, %Y'),
          confirmation_number:
        }

        notification_email = SimpleFormsApi::Notification::FormUploadEmail.new(config, notification_type: :confirmation)
        notification_email.send
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
