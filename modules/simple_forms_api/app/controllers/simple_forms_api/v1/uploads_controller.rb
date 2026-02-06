# frozen_string_literal: true

require 'datadog'
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
        '21-4140' => 'vba_21_4140',
        '21-4142' => 'vba_21_4142',
        '21P-0537' => 'vba_21p_0537',
        '21P-0847' => 'vba_21p_0847',
        '21P-601' => 'vba_21p_601',
        '26-4555' => 'vba_26_4555',
        '40-0247' => 'vba_40_0247',
        '40-10007' => 'vba_40_10007',
        '40-1330M' => 'vba_40_1330m'
      }.freeze

      UNAUTHENTICATED_FORMS = %w[40-0247 21-10210 21P-0847 40-10007 40-1330M 21P-0537 21P-601].freeze

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])

        response = if intent_service.use_intent_api?
                     handle_210966_authenticated
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
        return unless %w[40-0247 20-10207 40-10007 40-1330M 21-4140 21P-601].include?(params[:form_id])

        attachment = PersistentAttachments::MilitaryRecords.new(form_id: params[:form_id])
        attachment.file = params['file']
        file_path = params['file'].tempfile.path

        return unless validate_document_if_needed(file_path)

        raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

        attachment.save
        render json: PersistentAttachmentSerializer.new(attachment)
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

      def validate_document_if_needed(file_path)
        return true unless %w[40-0247 40-10007 21-4140].include?(params[:form_id]) &&
                           File.extname(file_path).downcase == '.pdf'

        service = BenefitsIntakeService::Service.new
        service.valid_document?(document: file_path)
        true
      rescue BenefitsIntakeService::Service::InvalidDocumentError => e
        if params[:form_id] == '40-10007'
          detail_msg = "We weren't able to upload your file. Make sure the file is in an " \
                       'accepted format and size before continuing.'
          render json: {
            errors: [{
              detail: detail_msg
            }]
          }, status: :unprocessable_entity
        else
          msg = "Document validation failed: #{e.message}"
          render json: { error: msg }, status: :unprocessable_entity
        end
        false
      end

      def lighthouse_service
        @lighthouse_service ||= BenefitsIntake::Service.new
      end

      def skip_authentication?
        UNAUTHENTICATED_FORMS.include?(params[:form_number]) || UNAUTHENTICATED_FORMS.include?(params[:form_id])
      end

      def intent_service
        @intent_service ||= SimpleFormsApi::IntentToFile.new(@current_user, params)
      end

      def handle_210966_authenticated
        parsed_form_data = JSON.parse(params.to_json)
        form = SimpleFormsApi::VBA210966.new(parsed_form_data)
        existing_intents = intent_service.existing_intents
        confirmation_number, expiration_date = intent_service.submit
        form.track_user_identity(confirmation_number)

        send_intent_received_email(parsed_form_data, confirmation_number, expiration_date) if confirmation_number

        json_for210966(confirmation_number, expiration_date, existing_intents)
      rescue Common::Exceptions::UnprocessableEntity, Exceptions::BenefitsClaimsApiDownError => e
        # Common::Exceptions::UnprocessableEntity: There is an authentication issue with the Intent to File API
        # Exceptions::BenefitsClaimsApiDownError: The Intent to File API is down or timed out
        # In either case, we revert to sending a PDF to Central Mail through the Benefits Intake API
        prepare_params_for_benefits_intake_and_log_error(e)
        submit_form_to_benefits_intake
      end

      def handle264555
        parsed_form_data = JSON.parse(params.to_json)
        form = SimpleFormsApi::VBA264555.new(parsed_form_data)

        raise Common::Exceptions::Unauthorized, 'ICN is required for LGY service' if icn.blank?

        lgy_response = LGY::Service.new(icn:).post_grant_application(payload: form.as_payload)
        reference_number = lgy_response.body['reference_number']
        status = lgy_response.body['status']
        Rails.logger.info(
          'Simple forms api - sent to lgy',
          { form_number: params[:form_number], status:, reference_number: }
        )

        case status
        when 'VALIDATED', 'ACCEPTED'
          send_sahsha_email(parsed_form_data, :confirmation, reference_number)
        when 'REJECTED'
          send_sahsha_email(parsed_form_data, :rejected, reference_number)
        when 'DUPLICATE'
          send_sahsha_email(parsed_form_data, :duplicate)
        end

        { json: { reference_number:, status:, submission_api: 'sahsha' }, status: lgy_response.status }
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
          send_confirmation_email_safely(parsed_form_data, confirmation_number)

          presigned_s3_url = upload_pdf_to_s3(confirmation_number, file_path, metadata, submission, form)

          add_vsi_flash_safely(form, submission)
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

        if %w[vba_40_0247 vba_40_10007 vba_40_1330m vba_21p_601].include?(form_id)
          raise "Generated PDF does not exist: #{file_path}" unless File.exist?(file_path)

          form.handle_attachments(file_path)
        end

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
          attachments: %w[vba_20_10207 vba_21_4140].include?(form_id) ? form.get_attachments : nil
        }.compact

        lighthouse_service.perform_upload(**upload_params)
      end

      def upload_pdf_to_s3(id, file_path, metadata, submission, form)
        return unless %w[production staging test].include?(Settings.vsp_environment)

        config = SimpleFormsApi::FormRemediation::Configuration::VffConfig.new
        attachments = %w[vba_20_10207 vba_21_4140].include?(form_id) ? form.get_attachments : []
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
        { confirmation_number:, submission_api: 'benefitsIntake' }.tap do |json|
          json[:pdf_url] = pdf_url if pdf_url.present?
          json[:expiration_date] = 1.year.from_now if form_id == 'vba_21_0966'
        end
      end

      def prepare_params_for_benefits_intake_and_log_error(e)
        params['veteran_full_name'] ||= {
          'first' => params['full_name']['first'],
          'last' => params['full_name']['last']
        }
        params['veteran_id'] ||= { 'ssn' => params['ssn'] }
        params['veteran_mailing_address'] ||= { 'postal_code' => @current_user.address[:postal_code] || '00000' }
        Rails.logger.info(
          'Simple forms api - 21-0966 Benefits Claims Intent to File API error,' \
          'reverting to filling a PDF and sending it to Benefits Intake API',
          {
            error: e,
            is_current_user_participant_id_present: @current_user.participant_id ? true : false,
            current_user_account_uuid: @current_user.user_account_uuid
          }
        )
      end

      def json_for210966(confirmation_number, expiration_date, existing_intents)
        { json: {
          confirmation_number:,
          expiration_date:,
          compensation_intent: existing_intents['compensation'],
          pension_intent: existing_intents['pension'],
          survivor_intent: existing_intents['survivor'],
          submission_api: 'intentToFile'
        } }
      end

      def send_confirmation_email(parsed_form_data, confirmation_number)
        config = {
          form_data: parsed_form_data,
          form_number: form_id,
          confirmation_number:,
          date_submitted: Time.zone.today.strftime('%B %d, %Y')
        }
        notification_email = SimpleFormsApi::Notification::Email.new(
          config,
          notification_type: :confirmation,
          user: @current_user
        )
        notification_email.send
      end

      def send_intent_received_email(parsed_form_data, confirmation_number, expiration_date)
        config = {
          form_data: parsed_form_data,
          form_number: 'vba_21_0966_intent_api',
          confirmation_number:,
          date_submitted: Time.zone.today.strftime('%B %d, %Y'),
          expiration_date: Time.zone.parse(expiration_date).strftime('%B %d, %Y')
        }
        notification_email = SimpleFormsApi::Notification::Email.new(
          config,
          notification_type: :received,
          user: @current_user
        )
        notification_email.send
      end

      def send_sahsha_email(parsed_form_data, notification_type, confirmation_number = nil)
        config = {
          form_data: parsed_form_data,
          form_number: 'vba_26_4555',
          confirmation_number:,
          date_submitted: Time.zone.today.strftime('%B %d, %Y')
        }
        notification_email = SimpleFormsApi::Notification::Email.new(
          config,
          notification_type:,
          user: @current_user
        )
        notification_email.send
      end

      def send_confirmation_email_safely(parsed_form_data, confirmation_number)
        send_confirmation_email(parsed_form_data, confirmation_number)
      rescue => e
        Rails.logger.error('Simple forms api - error sending confirmation email', error: e)
      end

      def add_vsi_flash_safely(form, submission)
        return unless Flipper.enabled?(:priority_processing_request_apply_vsi_flash, @current_user)

        if form.respond_to?(:add_vsi_flash) && params[:form_number] == '20-10207'
          form.add_vsi_flash

          Rails.logger.info('Simple Forms API - VSI Flash Applied', submission_id: submission.id)
        end
      rescue => e
        Rails.logger.error('Simple Forms API - Controller-level VSI Flash Error', error: e.message,
                                                                                  submission_id: submission.id)
      end
    end
  end
end
