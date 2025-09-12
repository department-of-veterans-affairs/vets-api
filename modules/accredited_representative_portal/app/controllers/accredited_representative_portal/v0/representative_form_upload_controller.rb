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
      before_action only: %i[submit upload_scanned_form upload_supporting_documents] do
        deny_access_unless_form_enabled(form_id)
      end

      # rubocop:disable Metrics/MethodLength
      def submit
        ar_monitoring.trace('ar.claims.form_upload.submit') do |span|
          service = SavedClaimService::Create

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
          span.set_tag('form_submission.organization', organization)

          trace_key_tags(span, form_id:, org: organization)

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
        if params[:form_id].present?
          params[:form_id].gsub(/-UPLOAD/, '')
        else
          submit_params[:formData][:formNumber]
        end
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

          span.set_tag('form_upload.form_id', attachment.form_id)
          span.set_tag('form_upload.attachment_type', model_klass.name)
          trace_key_tags(span, form_id:, org: organization)

          if params[:file].respond_to?(:original_filename)
            span.set_tag('form_upload.file_name', params[:file].original_filename)
          end
          span.set_tag('form_upload.file_size', params[:file].size) if params[:file].respond_to?(:size)

          json = serializer_klass.new(attachment).as_json.deep_transform_keys! { |key| key.camelize(:lower) }

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
        org_tag = "org:#{organization}" if organization.present?

        @ar_monitoring ||= AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags: [
            "controller:#{controller_name}",
            "action:#{action_name}",
            org_tag
          ].compact
        )
      end

      def form_class
        SavedClaim::BenefitsIntake.form_class_from_proper_form_id(form_id)
      end

      def organization
        claimant_representative&.to_h&.[](:power_of_attorney_holder_poa_code)
      rescue => e
        Rails.logger.warn("Org lookup failed: #{e.class} #{e.message}")
        nil
      end

      def trace_key_tags(span, **tags)
        tags.each do |tag, value|
          span.set_tag(tag, value) if value.present?
          Datadog::Tracing.active_trace&.set_tag(tag, value) if value.present?
        end
      end
    end
  end
end
