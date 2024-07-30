# frozen_string_literal: true

require 'ddtrace'
require 'simple_forms_api_submission/metadata_validator'
require 'lgy/service'
require 'lighthouse/benefits_intake/service'

module SimpleFormsApi
  module V1
    class UploadsController < ApplicationController
      skip_before_action :authenticate
      before_action :load_user
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
          render json: attachment
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
            form_data: parsed_form_data, form_number: get_form_id, confirmation_number:, user: @current_user
          ).send
        end

        json_for210966(confirmation_number, expiration_date, existing_intents)
      rescue Common::Exceptions::UnprocessableEntity => e
        # There is an authentication issue with the Intent to File API so we revert to sending a PDF to Central Mail
        # through the Benefits Intake API
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
        form_id = get_form_id
        parsed_form_data = JSON.parse(params.to_json)
        file_path, metadata, form = get_file_paths_and_metadata(parsed_form_data)

        if Flipper.enabled?(:simple_forms_lighthouse_benefits_intake_service)
          status, confirmation_number = upload_pdf(file_path, metadata, form_id)
        else
          status, confirmation_number = SimpleFormsApi::PdfUploader.new(file_path, metadata,
                                                                        form_id).upload_to_benefits_intake(params)
        end

        form.track_user_identity(confirmation_number)

        Rails.logger.info(
          'Simple forms api - sent to benefits intake',
          { form_number: params[:form_number], status:, uuid: confirmation_number }
        )

        if status == 200 && Flipper.enabled?(:simple_forms_email_confirmations)
          SimpleFormsApi::ConfirmationEmail.new(
            form_data: parsed_form_data, form_number: form_id, confirmation_number:, user: @current_user
          ).send
        end

        { json: get_json(confirmation_number || nil, form_id), status: }
      end

      def get_file_paths_and_metadata(parsed_form_data)
        form_id = get_form_id
        form = "SimpleFormsApi::#{form_id.titleize.gsub(' ', '')}".constantize.new(parsed_form_data)
        if form_id == 'vba_21_0966' && params[:preparer_identification] == 'VETERAN'
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

        form.handle_attachments(file_path) if %w[vba_40_0247 vba_20_10207 vba_40_10007].include? form_id

        [file_path, metadata, form]
      end

      def upload_pdf(file_path, metadata, form_id)
        lighthouse_service = BenefitsIntake::Service.new
        location, uuid = lighthouse_service.request_upload
        SimpleFormsApi::PdfStamper.stamp4010007_uuid(uuid) if form_id == 'vba_40_10007'
        form_submission = FormSubmission.create(
          form_type: params[:form_number],
          benefits_intake_uuid: uuid,
          form_data: params.to_json,
          user_account: @current_user&.user_account
        )
        FormSubmissionAttempt.create(form_submission:)

        Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
        Rails.logger.info(
          'Simple forms api - preparing to upload PDF to benefits intake',
          { location:, uuid: }
        )
        response = lighthouse_service.perform_upload(metadata: metadata.to_json, document: file_path,
                                                     upload_url: location)

        [response.status, uuid]
      end

      def form_is264555_and_should_use_lgy_api
        # TODO: Remove comment octothorpe and ALWAYS require icn
        params[:form_number] == '26-4555' # && icn
      end

      def icn
        @current_user&.icn
      end

      def get_form_id
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
        { json: {
          confirmation_number:,
          expiration_date:,
          compensation_intent: existing_intents['compensation'],
          pension_intent: existing_intents['pension'],
          survivor_intent: existing_intents['survivor']
        } }
      end
    end
  end
end
