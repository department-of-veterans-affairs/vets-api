# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'simple_forms_api_submission/metadata_validator'
require 'accredited_representative_portal/monitor'

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

          send_confirmation_email(saved_claim)
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
        fid = params[:form_id].presence || submit_params.dig(:formData, :formNumber)
        fid&.to_s&.gsub(/-UPLOAD\z/, '')
      end

      def send_confirmation_email(saved_claim)
        AccreditedRepresentativePortal::NotificationEmail.new(saved_claim.id).deliver(:confirmation)
      rescue => e
        monitor(saved_claim).track_send_email_failure(saved_claim, intake_service, user_account_id, 'confirmation', e)
      end

      def monitor(claim)
        @monitor ||= AccreditedRepresentativePortal::Monitor.new(claim:)
      end

      def intake_service
        @intake_service ||= ::BenefitsIntake::Service.new
      end

      def user_account_id
        return @user_account_id if defined?(@user_account_id)

        unless current_user&.icn
          @user_account_id = nil
          return @user_account_id
        end

        user_account = UserAccount.find_by(icn: current_user.icn)
        @user_account_id = user_account&.id

        Rails.logger.warn("UserAccount not found for ICN: #{current_user.icn}") unless @user_account_id

        @user_account_id
      end

      def authorize_attachment_upload
        # Require form_id for upload endpoints
        fid = form_id
        raise Common::Exceptions::ParameterMissing, 'form_id' if fid.blank?

        # Optionally validate it maps to a known class
        unless SavedClaim::BenefitsIntake.form_class_from_proper_form_id(fid)
          raise Common::Exceptions::UnprocessableEntity, detail: "Unknown form_id #{fid.inspect}"
        end

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

          # --- Validate inputs early ---
          uploaded_file = params[:file]
          span.set_tag('validation.file_present', uploaded_file.present?)
          raise Common::Exceptions::ParameterMissing, 'file' if uploaded_file.blank?

          fid = form_id
          span.set_tag('incoming.form_id_param', params[:form_id])
          span.set_tag('resolved.form_id', fid)

          klass = form_class
          unless klass
            span.set_tag('error.specific_reason', 'unknown_form_id')
            span.set_tag('validation.form_class_present', klass.present?)
            raise Common::Exceptions::UnprocessableEntity, detail: "Unknown form_id #{fid.inspect}"
          end

          # --- Perform attach ---
          attachment = service.perform(
            model_klass,
            file: uploaded_file,
            form_id: klass::PROPER_FORM_ID
          )

          # --- Trace metadata ---
          span.set_tag('form_upload.form_id', attachment.form_id)
          span.set_tag('form_upload.attachment_type', model_klass.name)
          if uploaded_file.respond_to?(:original_filename)
            span.set_tag('form_upload.file_name', uploaded_file.original_filename)
          end
          span.set_tag('form_upload.file_size', uploaded_file.size) if uploaded_file.respond_to?(:size)

          # --- Serialize & respond ---
          json = serializer_klass
                 .new(attachment)
                 .as_json
                 .deep_transform_keys { |k| k.to_s.camelize(:lower) }

          render json:, status: :ok
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
