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

      ATTEMPT_METRIC_SUBMIT = 'ar.claims.form_upload.submit.attempt'
      SUCCESS_METRIC_SUBMIT = 'ar.claims.form_upload.submit.success'
      ERROR_METRIC_SUBMIT = 'ar.claims.form_upload.submit.error'

      # rubocop:disable Metrics/MethodLength
      def submit
        monitoring = ar_monitoring(with_organization: true)
        monitoring.trace('ar.claims.form_upload.submit') do |span|
          monitoring.track_count(
            ATTEMPT_METRIC_SUBMIT,
            tags: ["form_id:#{form_id}"]
          )

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
          trace_key_tags(span, form_id:, org: organization)

          monitoring.track_count(
            SUCCESS_METRIC_SUBMIT,
            tags: ["form_id:#{form_id}"]
          )

          send_confirmation_email(saved_claim)
          render json: {
            confirmationNumber: confirmation_number,
            status: '200'
          }
        rescue service::RecordInvalidError => e
          span.set_tag('error.specific_reason', 'record_invalid')
          monitoring.track_count(
            ERROR_METRIC_SUBMIT,
            tags: ['reason:record_invalid', "form_id:#{form_id}"]
          )
          raise Common::Exceptions::ValidationErrors, e.record
        rescue service::WrongAttachmentsError => e
          span.set_tag('error.specific_reason', 'wrong_attachments')
          monitoring.track_count(
            ERROR_METRIC_SUBMIT,
            tags: ['reason:wrong_attachments', "form_id:#{form_id}"]
          )
          raise Common::Exceptions::UnprocessableEntity, detail: e.message
        rescue service::TooManyRequestsError
          span.set_tag('error.specific_reason', 'too_many_requests')
          monitoring.track_count(
            ERROR_METRIC_SUBMIT,
            tags: ['reason:too_many_requests', "form_id:#{form_id}"]
          )
          raise Common::Exceptions::ServiceUnavailable, detail: 'Temporary system issue'
        rescue service::UnknownError => e
          span.set_tag('error.specific_reason', 'unknown_error')
          monitoring.track_count(
            ERROR_METRIC_SUBMIT,
            tags: ['reason:unknown_error', "form_id:#{form_id}"]
          )
          raise Common::Exceptions::InternalServerError, e.cause
        end
      end
      # rubocop:enable Metrics/MethodLength

      def upload_scanned_form
        ar_monitoring(with_organization: false).trace('ar.claims.form_upload.upload_scanned_form') do |_span|
          handle_attachment_upload(
            PersistentAttachments::VAForm,
            PersistentAttachmentVAFormSerializer
          )
        end
      end

      def upload_supporting_documents
        ar_monitoring(with_organization: false).trace('ar.claims.form_upload.upload_supporting_documents') do |_span|
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
        monitor(saved_claim).track_send_email_failure(saved_claim, intake_service, current_user.user_account_uuid,
                                                      'confirmation', e)
      end

      def monitor(claim)
        @monitor ||= AccreditedRepresentativePortal::Monitor.new(claim:)
      end

      def intake_service
        @intake_service ||= ::BenefitsIntake::Service.new
      end

      def authorize_attachment_upload
        authorize(nil, policy_class: RepresentativeFormUploadPolicy)
      end

      def authorize_submission
        ar_monitoring(with_organization: true).trace('ar.claims.form_upload.authorize_submission') do |_span|
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
        ar_monitoring(with_organization: false).trace('ar.claims.form_upload.handle_attachment_upload') do |span|
          service = SavedClaimService::Attach

          attachment = service.perform(
            model_klass,
            file: params[:file],
            form_id: form_class::PROPER_FORM_ID
          )

          span.set_tag('form_upload.form_id', attachment.form_id)
          span.set_tag('form_upload.attachment_type', model_klass.name)
          trace_key_tags(span, form_id:)

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

      def ar_monitoring(with_organization:)
        org_tag = ("org:#{organization}" if with_organization && organization.present?)

        AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags: [
            "controller:#{controller_name}",
            "action:#{action_name}",
            org_tag,
            ('org_resolve:failed' if with_organization && org_tag.nil?)
          ].compact
        )
      end

      def form_class
        SavedClaim::BenefitsIntake.form_class_from_proper_form_id(form_id)
      end

      def organization
        claimant_representative&.power_of_attorney_holder&.poa_code
      rescue AccreditedRepresentativePortal::ClaimantRepresentative::Finder::Error
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
