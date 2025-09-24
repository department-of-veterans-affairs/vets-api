# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'simple_forms_api_submission/metadata_validator'

module SimpleFormsApi
  module V1
    class ScannedFormUploadsController < ApplicationController
      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])
        check_for_changes

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
        render json: PersistentAttachmentVAFormSerializer.new(attachment)
      end

      def upload_supporting_documents
        unless Flipper.enabled?(:simple_forms_upload_supporting_documents, @current_user)
          render json: { error: 'Feature not available' }, status: :not_found
          return
        end

        attachment = PersistentAttachments::VAForm.new
        attachment.form_id = params['form_id']
        attachment.file = params['file']

        raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

        processor = SimpleFormsApi::ScannedFormProcessor.new(attachment)
        processed_attachment = processor.process!

        render json: PersistentAttachmentVAFormSerializer.new(processed_attachment)
      rescue SimpleFormsApi::ScannedFormProcessor::ConversionError,
             SimpleFormsApi::ScannedFormProcessor::ValidationError => e
        render json: { errors: e.errors }, status: :unprocessable_entity
      end

      private

      def lighthouse_service
        @lighthouse_service ||= BenefitsIntake::Service.new
      end

      def upload_response
        if Flipper.enabled?(:simple_forms_upload_supporting_documents, @current_user)
          upload_response_with_supporting_documents
        else
          upload_response_legacy
        end
      end

      def upload_response_legacy
        file_path = find_attachment_path(params[:confirmation_code])
        stamper = PdfStamper.new(stamped_template_path: file_path, current_loa: @current_user.loa[:current],
                                 timestamp: Time.current)
        stamper.stamp_pdf
        metadata = validated_metadata
        status, confirmation_number = upload_pdf(file_path, metadata)
        file_size = File.size(file_path).to_f / (2**20)

        Rails.logger.info(
          'Simple forms api - scanned form uploaded',
          { form_number: params[:form_number], status:, confirmation_number:, file_size: }
        )
        [status, confirmation_number]
      end

      def upload_response_with_supporting_documents
        main_attachment = PersistentAttachment.find_by(guid: params[:confirmation_code])
        main_file_path = main_attachment.file.open.path

        supporting_attachments = []
        if params[:supporting_documents].present?
          confirmation_codes = params[:supporting_documents].map { |doc| doc[:confirmation_code] }
          supporting_attachments = PersistentAttachment.where(guid: confirmation_codes)
        end

        stamper = PdfStamper.new(stamped_template_path: main_file_path, current_loa: @current_user.loa[:current],
                                 timestamp: Time.current)
        stamper.stamp_pdf

        metadata = validated_metadata
        status, confirmation_number = upload_pdf_with_attachments(main_file_path, supporting_attachments, metadata)

        file_size = File.size(main_file_path).to_f / (2**20)

        Rails.logger.info(
          'Simple forms api - scanned form uploaded',
          { form_number: params[:form_number], status:, confirmation_number:, file_size: }
        )
        [status, confirmation_number]
      end

      def find_attachment_path(confirmation_code)
        PersistentAttachment.find_by(guid: confirmation_code).to_pdf.to_s
      end

      def validated_metadata
        raw_metadata = {
          'veteranFirstName' => params.dig(:form_data, :full_name, :first),
          'veteranLastName' => params.dig(:form_data, :full_name, :last),
          'fileNumber' => params.dig(:form_data, :id_number, :ssn) ||
                          params.dig(:form_data, :id_number, :va_file_number),
          'zipCode' => params.dig(:form_data, :postal_code),
          'source' => 'VA Platform Digital Forms',
          'docType' => params[:form_number],
          'businessLine' => 'CMP'
        }
        SimpleFormsApiSubmission::MetadataValidator.validate(raw_metadata)
      end

      def upload_pdf(file_path, metadata)
        location, uuid = prepare_for_upload
        log_upload_details(location, uuid)
        response = perform_pdf_upload(location, file_path, metadata)
        [response.status, uuid]
      end

      def upload_pdf_with_attachments(main_file_path, supporting_attachments, metadata)
        location, uuid = prepare_for_upload
        log_upload_details(location, uuid)
        attachments = supporting_attachments.map do |attachment|
          attachment.file.open.path
        end

        response = lighthouse_service.perform_upload(
          metadata: metadata.to_json,
          document: main_file_path,
          upload_url: location,
          attachments:
        )

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
          form_type: params[:form_number],
          form_data: params[:form_data].to_json,
          user_account: @current_user&.user_account
        )
      end

      def log_upload_details(location, uuid)
        Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
        Rails.logger.info('Simple forms api - preparing to upload scanned PDF to benefits intake', { location:, uuid: })
      end

      def perform_pdf_upload(location, file_path, metadata)
        lighthouse_service.perform_upload(
          metadata: metadata.to_json,
          document: file_path,
          upload_url: location
        )
      end

      def check_for_changes
        in_progress_form = InProgressForm.form_for_user('FORM-UPLOAD-FLOW', @current_user)
        if in_progress_form
          prefill_data_service = SimpleFormsApi::PrefillDataService.new(prefill_data: in_progress_form.form_data,
                                                                        form_data: params[:form_data],
                                                                        form_id: params[:form_number])
          prefill_data_service.check_for_changes
        end
      end

      def send_confirmation_email(params, confirmation_number)
        config = {
          form_number: params[:form_number],
          form_data: params[:form_data],
          date_submitted: Time.zone.today.strftime('%B %d, %Y'),
          confirmation_number:
        }
        notification_email = SimpleFormsApi::Notification::FormUploadEmail.new(config, notification_type: :confirmation)
        notification_email.send
      end
    end
  end
end
