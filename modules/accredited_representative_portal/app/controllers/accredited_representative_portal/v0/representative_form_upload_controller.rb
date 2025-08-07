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

      # rubocop:disable Metrics/MethodLength
      def submit
        ar_monitoring.trace('ar.claims.form_upload.submit') do |span|
          service = SavedClaimService::Create
          current_form_number = metadata[:formNumber]

          # Tags for tracing
          span.set_tag('form_id', current_form_number)
          Datadog::Tracing.active_trace&.set_tag('form_id', current_form_number)

          saved_claim = service.perform(
            type: form_class,
            metadata:,
            attachment_guids:,
            claimant_representative:
          )

          confirmation_number = saved_claim
                                .latest_submission_attempt
                                .benefits_intake_uuid

          span.set_tag('form_submission.status', '200')
          span.set_tag('form_submission.confirmation_number', confirmation_number)

          render json: {
            confirmationNumber: confirmation_number,
            status: '200'
          }
        rescue service::RecordInvalidError => e
          span.set_tag('error.specific_reason', 'record_invalid')
          raise Common::Exceptions::ValidationErrors, e.record
        rescue service::WrongAttachmentsError => e
          span.set_tag('error.specific_reason', 'wrong_attachments')
          raise Common::Exceptions::UnprocessableEntity, detail: e.message
        rescue service::UnknownError => e
          span.set_tag('error.specific_reason', 'unknown_error')
          raise Common::Exceptions::InternalServerError, e.cause
        end
      end
      # rubocop:enable Metrics/MethodLength

      def upload_scanned_form
        ar_monitoring.trace('ar.claims.form_upload.upload_scanned_form') do |_span|
          handle_attachment_upload(
            PersistentAttachments::VAForm,
            PersistentAttachmentVAFormSerializer
          )
        end
      end

      def upload_supporting_documents
        ar_monitoring.trace('ar.claims.form_upload.upload_supporting_documents') do |_span|
          handle_attachment_upload(
            PersistentAttachments::VAFormDocumentation,
            PersistentAttachmentSerializer
          )
        end
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
        ar_monitoring.trace('ar.claims.form_upload.authorize_submission') do |_span|
          claimant_icn.present? or
            raise Common::Exceptions::RecordNotFound,
                  'Could not lookup claimant with given information.'

          authorize(
            claimant_representative,
            policy_class: RepresentativeFormUploadPolicy
          )
        end
      end

      # rubocop:disable Metrics/MethodLength
      def handle_attachment_upload(model_klass, serializer_klass)
        ar_monitoring.trace('ar.claims.form_upload.handle_attachment_upload') do |span|
          service = SavedClaimService::Attach

          attachment = service.perform(
            model_klass,
            file: params[:file],
            form_id: form_class::PROPER_FORM_ID
          )

          # Trace tags
          span.set_tag('form_upload.form_id', attachment.form_id)
          span.set_tag('form_upload.attachment_type', model_klass.name)
          if params['file'].respond_to?(:original_filename)
            span.set_tag('form_upload.file_name', params['file'].original_filename)
          end
          span.set_tag('form_upload.file_size', params['file'].size) if params['file'].respond_to?(:size)

          json = serializer_klass.new(attachment).as_json.deep_transform_keys(&:camelize).deep_transform_keys! do |key|
            key.camelize(:lower)
          end

          render json:
        rescue service::RecordInvalidError => e
          span.set_tag('error.specific_reason', 'record_invalid')
          raise Common::Exceptions::ValidationErrors, e.record
        rescue service::UpstreamInvalidError => e
          span.set_tag('error.specific_reason', 'upstream_invalid')
          raise Common::Exceptions::UpstreamUnprocessableEntity, detail: e.message
        rescue service::UnknownError => e
          span.set_tag('error.specific_reason', 'unknown_error')
          raise Common::Exceptions::InternalServerError, e.cause
        end
      end
      # rubocop:enable Metrics/MethodLength

      def ar_monitoring
        @ar_monitoring ||= AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags: ["controller:#{controller_name}", "action:#{action_name}"]
        )
      end

      def form_class
        SavedClaim::BenefitsIntake.form_class_from_proper_form_id(form_id)
      end
    end
  end
end
