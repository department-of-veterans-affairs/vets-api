# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'simple_forms_api_submission/metadata_validator'

module AccreditedRepresentativePortal
  module V0
    class RepresentativeFormUploadController < ApplicationController
      include AccreditedRepresentativePortal::V0::RepresentativeFormUploadConcern

      VALID_FORM_NUMBERS = %w[21-686c].freeze

      def submit
        ar_monitoring.trace('ar.claims.form_upload.submit') do |span|
          authorize(get_icn, policy_class: RepresentativeFormUploadPolicy)
          Datadog::Tracing.active_trace&.set_tag('form_id', form_data[:formNumber])
          span.set_tag('form_id', form_data[:formNumber])

          status, confirmation_number = upload_response

          span.set_tag('form_submission.status', status)
          span.set_tag('form_submission.confirmation_number', confirmation_number)

          render json: { status:, confirmation_number: }
        end
      end

      def upload_scanned_form
        ar_monitoring.trace('ar.claims.form_upload.upload_scanned_form') do |_span|
          authorize(nil, policy_class: RepresentativeFormUploadPolicy)
          handle_attachment_upload(PersistentAttachments::VAForm)
        end
      end

      def upload_supporting_documents
        ar_monitoring.trace('ar.claims.form_upload.upload_supporting_documents') do |_span|
          authorize(nil, policy_class: RepresentativeFormUploadPolicy)
          handle_attachment_upload(PersistentAttachments::VAFormDocumentation)
        end
      end

      private

      # rubocop:disable Metrics/MethodLength
      def handle_attachment_upload(attachment_type)
        ar_monitoring.trace('ar.claims.form_upload.handle_attachment_upload') do |span|
          attachment = create_attachment(attachment_type)
          span.set_tag('form_upload.form_id', attachment.form_id)
          if params['file'].respond_to?(:original_filename)
            span.set_tag('form_upload.file_name', params['file'].original_filename)
          end
          span.set_tag('form_upload.file_size', params['file'].size) if params['file'].respond_to?(:size)
          span.set_tag('form_upload.attachment_type', attachment_type.name)

          error = validate_attachment_upstream!(attachment)
          if error
            span.set_tag('error.specific_reason', 'Upstream document validation failed')
            return render_error("Document validation failed: #{error.message}")
          end

          error = validate_attachment!(attachment)
          if error
            span.set_tag('error.specific_reason', 'Attachment validation failed')
            return render_error("Document validation failed: #{error.message}")
          end

          attachment.save
          render json: serialized(attachment)
        end
      end
      # rubocop:enable Metrics/MethodLength

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

      # rubocop:disable Metrics/MethodLength
      def upload_response
        ar_monitoring.trace('ar.claims.form_upload.upload_response') do |span|
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

          span.set_tag('upload_response.status', status)
          span.set_tag('upload_response.confirmation_number', confirmation_number)
          span.set_tag('upload_response.file_size_mb', file_size)

          [status, confirmation_number]
        end
      end
      # rubocop:enable Metrics/MethodLength

      def find_attachment_path(confirmation_code)
        PersistentAttachment.find_by(guid: confirmation_code).to_pdf.to_s
      end

      def upload_pdf(file_path, metadata)
        ar_monitoring.trace('ar.claims.form_upload.upload_pdf_to_benefits_intake') do |span|
          location, uuid = prepare_for_upload
          log_upload_details(location, uuid)
          response = perform_pdf_upload(location, file_path, metadata)

          span.set_tag('benefits_intake.status', response.status)
          span.set_tag('benefits_intake.uuid', uuid)

          [response.status, uuid]
        end
      end

      def prepare_for_upload
        ar_monitoring.trace('ar.claims.form_upload.prepare_for_upload_request') do |span|
          location, uuid = lighthouse_service.request_upload
          create_form_submission_attempt(uuid)
          span.set_tag('benefits_intake.upload_location_present', !location.nil?)
          [location, uuid]
        end
      end

      def create_form_submission_attempt(uuid)
        ar_monitoring.trace('ar.claims.form_upload.create_form_submission_attempt_db') do |_span|
          FormSubmissionAttempt.transaction do
            form_submission = create_form_submission
            FormSubmissionAttempt.create(form_submission:, benefits_intake_uuid: uuid)
          end
        end
      end

      def create_form_submission
        ar_monitoring.trace('ar.claims.form_upload.create_form_submission_db') do |_span|
          FormSubmission.create(
            form_type: form_data[:formNumber],
            form_data: form_data.to_json,
            user_account: @current_user&.user_account
          )
        end
      end

      def log_upload_details(location, uuid)
        Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
        Rails.logger.info('Accredited Rep Form Upload - preparing to upload scanned PDF to benefits intake',
                          { location:, uuid: })
      end

      def perform_pdf_upload(location, file_path, metadata)
        ar_monitoring.trace('ar.claims.form_upload.perform_pdf_upload_api_call') do |_span|
          lighthouse_service.perform_upload(
            metadata: metadata.to_json,
            document: file_path,
            upload_url: location
          )
        end
      end

      def get_icn
        ar_monitoring.trace('ar.claims.form_upload.get_icn_from_mpi') do |span|
          mpi = MPI::Service.new.find_profile_by_attributes(ssn:, first_name:, last_name:, birth_date:)

          if mpi.profile&.icn
            mpi.profile.icn
          else
            span.set_tag('error.specific_reason', 'Could not lookup claimant with given information.')
            raise Common::Exceptions::RecordNotFound, 'Could not lookup claimant with given information.'
          end
        end
      end

      def ar_monitoring
        @ar_monitoring ||= AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags: ["controller:#{controller_name}", "action:#{action_name}"]
        )
      end
    end
  end
end
