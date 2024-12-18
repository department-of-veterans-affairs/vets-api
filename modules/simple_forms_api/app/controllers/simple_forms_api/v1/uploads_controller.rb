# frozen_string_literal: true

require 'ddtrace'
require 'simple_forms_api_submission/metadata_validator'
require 'lgy/service'
require 'lighthouse/benefits_intake/service'
require 'simple_forms_api/form_remediation/configuration/vff_config'
require 'benefits_intake_service/service'

module SimpleFormsApi
  module V1
    class UploadsController < ApplicationController
      skip_before_action :authenticate, if: :skip_authentication?
      before_action :load_user, if: :skip_authentication?
      skip_after_action :set_csrf_header

      FORM_NUMBER_MAP = {
        '20-10206' => 'vba_20_10206',
        '20-10207' => 'vba_20_10207',
        '21-0845' => 'vba_21_0845',
        '21-0966' => 'vba_21_0966',
        '21-0972' => 'vba_21_0972',
        '21-10210' => 'vba_21_10210',
        '21-4138' => 'vba_21_4138',
        '21-4142' => 'vba_21_4142',
        '21P-0847' => 'vba_21p_0847',
        '26-4555' => 'vba_26_4555',
        '40-0247' => 'vba_40_0247',
        '40-10007' => 'vba_40_10007'
      }.freeze

      UNAUTHENTICATED_FORMS = %w[40-0247 21-10210 21P-0847 40-10007].freeze

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])

        response = if intent_service.use_intent_api?
                     SimpleFormsApi::IntentToFile::Submission.new(@current_user, params).submit
                   elsif params[:form_number] == '26-4555'
                     handle264555
                   else
                     submit_form_to_benefits_intake
                   end
        clear_saved_form(params[:form_number])

        render response
      rescue Prawn::Errors::IncompatibleStringEncoding
        raise
      rescue => e
        raise Exceptions::ScrubbedUploadsSubmitError.new(params), e
      end

      def submit_supporting_documents
        if %w[40-0247 20-10207 40-10007].include?(params[:form_id])
          attachment = PersistentAttachments::MilitaryRecords.new(form_id: params[:form_id])
          attachment.file = params['file']
          file_path = params['file'].tempfile.path
          # Validate the document using BenefitsIntakeService
          if %w[40-0247 40-10007].include?(params[:form_id])
            begin
              service = BenefitsIntakeService::Service.new
              service.valid_document?(document: file_path)
            rescue BenefitsIntakeService::Service::InvalidDocumentError => e
              render json: { error: "Document validation failed: #{e.message}" }, status: :unprocessable_entity
              return
            end
          end
          raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

          attachment.save
          render json: PersistentAttachmentSerializer.new(attachment)
        end
      end

      def get_intents_to_file
        existing_intents = intent_service.existing_intents
        render json: {
          compensation_intent: existing_intents['compensation'],
          pension_intent: existing_intents['pension'],
          survivor_intent: existing_intents['survivor']
        }
      end

      private

      def lighthouse_service
        @lighthouse_service ||= BenefitsIntake::Service.new
      end

      def skip_authentication?
        UNAUTHENTICATED_FORMS.include?(params[:form_number]) || UNAUTHENTICATED_FORMS.include?(params[:form_id])
      end

      def intent_service
        @intent_service ||= SimpleFormsApi::SupportingForms::IntentToFile.new(@current_user, params)
      end

      def handle264555
        parsed_form_data = JSON.parse(params.to_json)
        form = SimpleFormsApi::VBA264555.new(parsed_form_data)
        lgy_response = LGY::Service.new.post_grant_application(payload: form.as_payload)
        reference_number = lgy_response.body['reference_number']
        status = lgy_response.body['status']
        Rails.logger.info(
          'Simple forms api - sent to lgy',
          { form_number: params[:form_number], status:, reference_number: }
        )
        { json: { reference_number:, status: }, status: lgy_response.status }
      end

      def submit_form_to_benefits_intake
        parsed_form_data = JSON.parse(params.to_json)
        file_path, metadata, form = get_file_paths_and_metadata(parsed_form_data)

        status, confirmation_number, submission = upload_pdf(file_path, metadata, form)

        form.track_user_identity(confirmation_number)

        Rails.logger.info(
          'Simple forms api - sent to benefits intake',
          { form_number: params[:form_number], status:, uuid: confirmation_number }
        )

        if status == 200
          if Flipper.enabled?(:simple_forms_email_confirmations)
            send_confirmation_email(parsed_form_data, confirmation_number)
          end

          presigned_s3_url = if Flipper.enabled?(:submission_pdf_s3_upload)
                               upload_pdf_to_s3(confirmation_number, file_path, metadata, submission, form)
                             end
        end

        build_response(confirmation_number, presigned_s3_url, status)
      rescue SimpleFormsApi::FormRemediation::Error => e
        Rails.logger.error('Simple forms api - error uploading form submission to S3 bucket', error: e)
        build_response(confirmation_number, presigned_s3_url, status)
      end

      def build_response(confirmation_number, presigned_s3_url, status)
        json = get_json(confirmation_number || nil, presigned_s3_url || nil)
        { json:, status: }
      end

      def get_file_paths_and_metadata(parsed_form_data)
        form = "SimpleFormsApi::#{form_id.titleize.gsub(' ', '')}".constantize.new(parsed_form_data)
        # This path can come about if the user is authenticated and, for some reason, doesn't have a participant_id
        if form_id == 'vba_21_0966' && params[:preparer_identification] == 'VETERAN' && @current_user
          form = form.populate_veteran_data(@current_user)
        end
        filler = SimpleFormsApi::PdfFiller.new(form_number: form_id, form:)

        file_path = if @current_user
                      filler.generate(@current_user.loa[:current])
                    else
                      filler.generate
                    end
        metadata = SimpleFormsApiSubmission::MetadataValidator.validate(form.metadata,
                                                                        zip_code_is_us_based: form.zip_code_is_us_based)

        form.handle_attachments(file_path) if %w[vba_40_0247 vba_40_10007].include?(form_id)

        [file_path, metadata, form]
      end

      def upload_pdf(file_path, metadata, form)
        location, uuid, submission = prepare_for_upload(form, file_path)
        log_upload_details(location, uuid)
        response = perform_pdf_upload(location, file_path, metadata, form)

        [response.status, uuid, submission]
      end

      def prepare_for_upload(form, file_path)
        Rails.logger.info('Simple forms api - preparing to request upload location from Lighthouse', form_id:)
        location, uuid = lighthouse_service.request_upload
        stamp_pdf_with_uuid(form, uuid, file_path)
        attempt = create_form_submission_attempt(uuid)

        [location, uuid, attempt.form_submission]
      end

      def stamp_pdf_with_uuid(form, uuid, stamped_template_path)
        # Stamp uuid on 40-10007
        pdf_stamper = SimpleFormsApi::PdfStamper.new(stamped_template_path:, form:)
        pdf_stamper.stamp_uuid(uuid)
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
          form_data: params.to_json,
          user_account: @current_user&.user_account
        )
      end

      def log_upload_details(location, uuid)
        Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
        Rails.logger.info('Simple forms api - preparing to upload PDF to benefits intake', { location:, uuid: })
      end

      def perform_pdf_upload(location, file_path, metadata, form)
        upload_params = {
          metadata: metadata.to_json,
          document: file_path,
          upload_url: location,
          attachments: form_id == 'vba_20_10207' ? form.get_attachments : nil
        }.compact

        lighthouse_service.perform_upload(**upload_params)
      end

      def upload_pdf_to_s3(id, file_path, metadata, submission, form)
        config = SimpleFormsApi::FormRemediation::Configuration::VffConfig.new
        attachments = form_id == 'vba_20_10207' ? form.get_attachments : []
        s3_client = config.s3_client.new(
          config:, type: :submission, id:, submission:, attachments:, file_path:, metadata:
        )
        s3_client.upload
      end

      def form_is264555_and_should_use_lgy_api
        params[:form_number] == '26-4555' && icn
      end

      def icn
        @current_user&.icn
      end

      def form_id
        form_number = params[:form_number]
        raise 'missing form_number in params' unless form_number

        FORM_NUMBER_MAP[form_number]
      end

      def get_json(confirmation_number, pdf_url)
        { confirmation_number: }.tap do |json|
          json[:pdf_url] = pdf_url if pdf_url.present?
          json[:expiration_date] = 1.year.from_now if form_id == 'vba_21_0966'
        end
      end

      def send_confirmation_email(parsed_form_data, confirmation_number)
        config = {
          form_data: parsed_form_data,
          form_number: form_id,
          confirmation_number:,
          date_submitted: Time.zone.today.strftime('%B %d, %Y')
        }
        notification_email = SimpleFormsApi::NotificationEmail.new(
          config,
          notification_type: :confirmation,
          user: @current_user
        )
        notification_email.send
      end
    end
  end
end
