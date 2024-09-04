# frozen_string_literal: true

require 'ddtrace'
require 'simple_forms_api_submission/metadata_validator'
require 'lgy/service'
require 'lighthouse/benefits_intake/service'

module SimpleFormsApi
  module V1
    class UploadsController < ApplicationController
      skip_before_action :authenticate, if: :skip_authentication?
      before_action :load_user, if: :skip_authentication?
      skip_after_action :set_csrf_header

      FORM_NUMBER_MAP = {
        '21-0966' => 'vba_21_0966',
        '21-0972' => 'vba_21_0972',
        '21-0845' => 'vba_21_0845',
        '21-10210' => 'vba_21_10210',
        '21-4138' => 'vba_21_4138',
        '21-4142' => 'vba_21_4142',
        '21P-0847' => 'vba_21p_0847',
        '26-4555' => 'vba_26_4555',
        '40-0247' => 'vba_40_0247',
        '20-10206' => 'vba_20_10206',
        '40-10007' => 'vba_40_10007',
        '20-10207' => 'vba_20_10207'
      }.freeze

      UNAUTHENTICATED_FORMS = %w[40-0247 21-10210 21P-0847 40-10007].freeze

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])

        response = if intent_service.use_intent_api?
                     handle_210966_authenticated
                   elsif form_is264555_and_should_use_lgy_api
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
        @intent_service ||= SimpleFormsApi::IntentToFile.new(@current_user, params)
      end

      def handle_210966_authenticated
        parsed_form_data = JSON.parse(params.to_json)
        form = SimpleFormsApi::VBA210966.new(parsed_form_data)
        existing_intents = intent_service.existing_intents
        confirmation_number, expiration_date = intent_service.submit
        form.track_user_identity(confirmation_number)

        if Flipper.enabled?(:simple_forms_email_confirmations)
          SimpleFormsApi::ConfirmationEmail.new(
            form_data: parsed_form_data, form_number: fetch_form_id, confirmation_number:, user: @current_user
          ).send
        end

        json_for210966(confirmation_number, expiration_date, existing_intents)
      rescue Common::Exceptions::UnprocessableEntity, Net::ReadTimeout => e
        # Common::Exceptions::UnprocessableEntity: There is an authentication issue with the Intent to File API
        # Faraday::TimeoutError: The Intent to File API is down or timed out
        # In either case, we revert to sending a PDF to Central Mail through the Benefits Intake API
        prepare_params_for_benefits_intake_and_log_error(e)
        submit_form_to_benefits_intake
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
        form_id = fetch_form_id
        parsed_form_data = JSON.parse(params.to_json)
        form_info = gather_form_info(parsed_form_data)

        status, confirmation_number = process_form_submission(form_info, params)

        form_info[:form].track_user_identity(confirmation_number)

        log_submission(form_id, params[:form_number], status, confirmation_number)

        send_confirmation_email(form_id, parsed_form_data, confirmation_number, status)

        generate_response(form_id, confirmation_number, status)
      end

      def process_form_submission(form_info, params)
        if Flipper.enabled?(:simple_forms_lighthouse_benefits_intake_service)
          upload_pdf_via_service(form_info)
        else
          upload_pdf_via_uploader(form_info, params)
        end
      end

      def upload_pdf_via_service(form_info)
        upload_pdf(
          form_info[:file_path],
          form_info[:metadata],
          form_info[:form],
          form_info[:attachments]
        )
      end

      def upload_pdf_via_uploader(form_info, params)
        uploader = SimpleFormsApi::PdfUploader.new(
          form_info[:file_path],
          form_info[:metadata],
          form_info[:form],
          form_info[:attachments]
        )
        uploader.upload_to_benefits_intake(params)
      end

      def log_submission(form_number, status, uuid)
        Rails.logger.info('Simple forms api - sent to benefits intake', { form_number:, status:, uuid: })
      end

      def send_confirmation_email(form_id, parsed_form_data, confirmation_number, status)
        return unless status == 200 && Flipper.enabled?(:simple_forms_email_confirmations)

        SimpleFormsApi::ConfirmationEmail.new(
          form_data: parsed_form_data,
          form_number: form_id,
          confirmation_number:,
          user: @current_user
        ).send
      end

      def generate_response(form_id, confirmation_number, status)
        { json: get_json(confirmation_number, form_id), status: }
      end

      def gather_form_info(parsed_form_data)
        form_id = fetch_form_id
        form = initialize_form(form_id, parsed_form_data)
        file_path = generate_filled_form(form_id, form)
        metadata = validate_metadata(form)

        handle_form_attachments(form, file_path, form_id)

        attachments = fetch_attachments(form, form_id)

        { file_path:, metadata:, form:, attachments: }
      end

      def initialize_form(form_id, parsed_form_data)
        form = "SimpleFormsApi::#{form_id.titleize.gsub(' ', '')}".constantize.new(parsed_form_data)

        # This path can come about if the user is authenticated and, for some reason, doesn't have a participant_id
        if form_id == 'vba_21_0966' && params[:preparer_identification] == 'VETERAN' && @current_user
          return form.populate_veteran_data(@current_user)
        end

        form
      end

      def generate_filled_form(form_id, form)
        filler = SimpleFormsApi::PdfFiller.new(form_number: form_id, form:)
        @current_user ? filler.generate(@current_user.loa[:current]) : filler.generate
      end

      def validate_metadata(form)
        SimpleFormsApiSubmission::MetadataValidator.validate(
          form.metadata,
          zip_code_is_us_based: form.zip_code_is_us_based
        )
      end

      def handle_form_attachments(form, file_path, form_id)
        form.handle_attachments(file_path) if %w[vba_40_0247 vba_40_10007].include?(form_id)
      end

      def fetch_attachments(form, form_id)
        form.get_attachments if form_id == 'vba_20_10207'
      end

      def upload_pdf(file_path, metadata, form, attachments)
        location, uuid = prepare_for_upload(form)
        log_upload_details(location, uuid)
        response = perform_pdf_upload(location, file_path, metadata, attachments)

        [response.status, uuid]
      end

      def prepare_for_upload(form)
        location, uuid = lighthouse_service.request_upload
        stamp_pdf_with_uuid(form, uuid)
        create_form_submission_attempt(uuid)

        [location, uuid]
      end

      def stamp_pdf_with_uuid(form, uuid)
        # Stamp uuid on 40-10007
        pdf_stamper = SimpleFormsApi::PdfStamper.new(stamped_template_path: 'tmp/vba_40_10007-tmp.pdf', form:)
        pdf_stamper.stamp_uuid(uuid)
      end

      def create_form_submission_attempt(uuid)
        form_submission = create_form_submission(uuid)
        FormSubmissionAttempt.create(form_submission:)
      end

      def create_form_submission(uuid)
        FormSubmission.create(
          form_type: params[:form_number],
          benefits_intake_uuid: uuid,
          form_data: params.to_json,
          user_account: @current_user&.user_account
        )
      end

      def log_upload_details(location, uuid)
        Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
        Rails.logger.info('Simple forms api - preparing to upload PDF to benefits intake', { location:, uuid: })
      end

      def perform_pdf_upload(upload_url, document, metadata, attachments)
        lighthouse_service.perform_upload(metadata: metadata.to_json, document:, upload_url:, attachments:)
      end

      def form_is264555_and_should_use_lgy_api
        params[:form_number] == '26-4555' && icn
      end

      def icn
        @current_user&.icn
      end

      def fetch_form_id
        form_number = params[:form_number]
        raise 'missing form_number in params' unless form_number

        FORM_NUMBER_MAP[form_number]
      end

      def get_json(confirmation_number, form_id)
        json = { confirmation_number: }
        json[:expiration_date] = 1.year.from_now if form_id == 'vba_21_0966'

        json
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
        {
          json: {
            confirmation_number:,
            expiration_date:,
            compensation_intent: existing_intents['compensation'],
            pension_intent: existing_intents['pension'],
            survivor_intent: existing_intents['survivor']
          }
        }
      end
    end
  end
end
