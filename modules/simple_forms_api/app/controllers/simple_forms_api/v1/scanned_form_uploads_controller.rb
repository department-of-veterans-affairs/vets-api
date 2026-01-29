# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'simple_forms_api_submission/metadata_validator'
require 'logging/helper/parameter_filter'

module SimpleFormsApi
  module V1
    class ScannedFormUploadsController < ApplicationController
      include Logging::Helper::ParameterFilter

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])
        check_for_changes

        status, confirmation_number = upload_response

        send_confirmation_email(params, confirmation_number) if status == 200

        render json: { status:, confirmation_number: }
      rescue SimpleFormsApi::ScannedFormUploadService::UploadError => e
        render json: { errors: e.errors }, status: e.http_status
      end

      def upload_scanned_form
        attachment = PersistentAttachments::VAForm.new
        attachment.form_id = params['form_id']

        attachment.file_attacher.attach(params['file'], validate: false)

        processor = SimpleFormsApi::ScannedFormProcessor.new(attachment, password: params['password'])
        processor.process!

        render json: PersistentAttachmentVAFormSerializer.new(attachment)
      rescue SimpleFormsApi::ScannedFormProcessor::ConversionError,
             SimpleFormsApi::ScannedFormProcessor::ValidationError => e
        render json: { errors: e.errors }, status: :unprocessable_entity
      end

      def upload_supporting_documents
        unless Flipper.enabled?(:simple_forms_upload_supporting_documents, @current_user)
          render json: { error: 'Feature not available' }, status: :not_found
          return
        end

        uploaded_file = extract_uploaded_file
        return unless uploaded_file

        attachment = PersistentAttachments::MilitaryRecords.new
        attachment.form_id = params['form_id']

        attachment.file_attacher.attach(uploaded_file, validate: false)

        processor = SimpleFormsApi::ScannedFormProcessor.new(attachment, password: params['password'])
        processed_attachment = processor.process!

        render json: PersistentAttachmentVAFormSerializer.new(processed_attachment)
      rescue SimpleFormsApi::ScannedFormProcessor::ConversionError,
             SimpleFormsApi::ScannedFormProcessor::ValidationError => e
        render json: { errors: e.errors }, status: :unprocessable_entity
      rescue SimpleFormsApi::ScannedFormProcessor::PersistenceError => e
        render json: { errors: e.errors }, status: :internal_server_error
      end

      private

      def normalized_params
        {
          form_number: params[:form_number],
          confirmation_code: params[:confirmation_code],
          form_data: params.require(:form_data).to_unsafe_h.deep_symbolize_keys,
          supporting_documents: Array(params[:supporting_documents]).map do |doc|
            doc.permit(:confirmation_code).to_h.symbolize_keys
          end
        }
      end

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

        stamper = PdfStamper.new(
          stamped_template_path: file_path,
          form_number: params[:form_number],
          current_loa: @current_user.loa[:current],
          timestamp: Time.current
        )
        stamper.stamp_pdf

        metadata = validated_metadata
        status, confirmation_number = upload_pdf(file_path, metadata)
        file_size = File.size(file_path).to_f / (2**20)

        Rails.logger.info(
          'Simple forms api - scanned form uploaded',
          filter_params(
            { form_number: params[:form_number], status:, confirmation_number:, file_size: },
            allowlist: %w[form_number status confirmation_number file_size]
          )
        )
        [status, confirmation_number]
      end

      def upload_response_with_supporting_documents
        service = SimpleFormsApi::ScannedFormUploadService.new(
          params: normalized_params,
          current_user: @current_user,
          lighthouse_service:
        )
        service.upload_with_supporting_documents
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
        form_data_with_attachments = normalized_params[:form_data].merge(
          confirmation_code: normalized_params[:confirmation_code],
          supporting_documents: normalized_params[:supporting_documents]
        )

        FormSubmission.create(
          form_type: normalized_params[:form_number],
          form_data: form_data_with_attachments.to_json,
          user_account: @current_user&.user_account
        )
      end

      def log_upload_details(location, uuid)
        Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
        Rails.logger.info(
          'Simple forms api - preparing to upload scanned PDF to benefits intake',
          filter_params(
            { location:, uuid: },
            allowlist: %w[uuid]
          )
        )
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

      def extract_uploaded_file
        file = params[:file] || params['file']
        if file.blank?
          render_upload_error('File missing', 'A file must be provided for upload.', :bad_request)
          return nil
        end

        unless valid_uploaded_file?(file)
          render_upload_error('Invalid file', 'The uploaded file is invalid or unreadable.', :unprocessable_entity)
          return nil
        end

        file
      end

      def valid_uploaded_file?(file)
        file.respond_to?(:read) && file.respond_to?(:size)
      rescue
        false
      end

      def render_upload_error(title, detail, status_code)
        render json: { errors: [{ title:, detail: }] }, status: status_code
      end
    end
  end
end
