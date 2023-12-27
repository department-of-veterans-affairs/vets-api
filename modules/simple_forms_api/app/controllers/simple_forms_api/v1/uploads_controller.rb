# frozen_string_literal: true

require 'ddtrace'
require 'simple_forms_api_submission/service'
require 'simple_forms_api_submission/metadata_validator'

module SimpleFormsApi
  module V1
    class UploadsController < ApplicationController
      skip_before_action :authenticate
      before_action :authenticate, if: :should_authenticate
      skip_after_action :set_csrf_header

      FORM_NUMBER_MAP = {
        '21-0966' => 'vba_21_0966',
        '21-0972' => 'vba_21_0972',
        '21-0845' => 'vba_21_0845',
        '21-10210' => 'vba_21_10210',
        '21-4142' => 'vba_21_4142',
        '21P-0847' => 'vba_21p_0847',
        '26-4555' => 'vba_26_4555',
        '10-10D' => 'vha_10_10d',
        '40-0247' => 'vba_40_0247',
        '20-10206' => 'vba_20_10206',
        '40-10007' => 'vba_40_10007'
      }.freeze

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])

        if form_is210966 && icn
          handle_210966_authenticated
        else
          submit_form_to_central_mail
        end
      rescue => e
        raise Exceptions::ScrubbedUploadsSubmitError.new(params), e
      end

      def submit_supporting_documents
        if params[:form_id] == '40-0247'
          attachment = PersistentAttachments::MilitaryRecords.new(form_id: '40-0247')
          attachment.file = params['file']
          raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

          attachment.save
          render json: attachment
        end
      end

      def authenticate
        super
      rescue Common::Exceptions::Unauthorized
        Rails.logger.info(
          "Simple forms api - unauthenticated user submitting form: #{params[:form_number]}"
        )
      end

      private

      def handle_210966_authenticated
        intent_service = SimpleFormsApi::IntentToFile.new(params, icn)
        existing_intents = intent_service.existing_intents
        confirmation_number, expiration_date = intent_service.submit

        render json: {
          confirmation_number:,
          expiration_date:,
          compensation_intent: existing_intents['compensation'],
          pension_intent: existing_intents['pension'],
          survivor_intent: existing_intents['survivor']
        }
      end

      def submit_form_to_central_mail
        parsed_form_data = form_is210966 ? handle_210966_data : JSON.parse(params.to_json)
        form_id = get_form_id
        filler = SimpleFormsApi::PdfFiller.new(form_number: form_id, data: parsed_form_data)

        file_path = filler.generate
        metadata = SimpleFormsApiSubmission::MetadataValidator.validate(filler.metadata)

        SimpleFormsApi::VBA400247.new(parsed_form_data).handle_attachments(file_path) if form_id == 'vba_40_0247'

        status, confirmation_number = upload_pdf_to_benefits_intake(file_path, metadata)

        if status == 200 && Flipper.enabled?(:simple_forms_email_confirmations)
          SimpleFormsApi::ConfirmationEmail.new(
            form_data: parsed_form_data, form_number: form_id, confirmation_number:, user: @current_user
          ).send
        end

        Rails.logger.info(
          "Simple forms api - sent to benefits intake: #{params[:form_number]},
            status: #{status}, uuid #{confirmation_number}"
        )

        json = { confirmation_number: }
        json[:expiration_date] = 1.year.from_now if form_id == 'vba_21_0966'

        render json:, status:
      end

      def get_upload_location_and_uuid(lighthouse_service)
        upload_location = lighthouse_service.get_upload_location.body
        {
          uuid: upload_location.dig('data', 'id'),
          location: upload_location.dig('data', 'attributes', 'location')
        }
      end

      def upload_pdf_to_benefits_intake(file_path, metadata)
        lighthouse_service = SimpleFormsApiSubmission::Service.new
        uuid_and_location = get_upload_location_and_uuid(lighthouse_service)
        form_submission = FormSubmission.create(
          form_type: params[:form_number],
          benefits_intake_uuid: uuid_and_location[:uuid],
          form_data: params.to_json,
          user_account: @current_user&.user_account
        )
        FormSubmissionAttempt.create(form_submission:)

        Datadog::Tracing.active_trace&.set_tag('uuid', uuid_and_location[:uuid])
        Rails.logger.info(
          "Simple forms api - preparing to upload PDF to benefits intake:
            location: #{uuid_and_location[:location]}, uuid: #{uuid_and_location[:uuid]}"
        )
        response = lighthouse_service.upload_doc(
          upload_url: uuid_and_location[:location],
          file: file_path,
          metadata: metadata.to_json
        )

        [response.status, uuid_and_location[:uuid]]
      end

      def form_is210966
        params[:form_number] == '21-0966'
      end

      def should_authenticate
        params[:form_number] == '21-0966' || params[:form_number] == '21-0845'
      end

      def icn
        @current_user&.icn
      end

      def handle_210966_data
        roles = {
          'fiduciary' => 'Fiduciary',
          'officer' => 'Veteran Service Officer',
          'alternate' => 'Alternate Signer'
        }
        data = JSON.parse(params.to_json)
        if data['third_party_preparer_role']
          data['third_party_preparer_role'] = (
            roles[data['third_party_preparer_role']] || data['other_third_party_preparer_role']
          ) || ''
        end

        data
      end

      def get_form_id
        form_number = params[:form_number]
        raise 'missing form_number in params' unless form_number

        FORM_NUMBER_MAP[form_number]
      end
    end
  end
end
