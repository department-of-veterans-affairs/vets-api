# frozen_string_literal: true

require 'ddtrace'
require 'simple_forms_api_submission/service'
require 'simple_forms_api_submission/metadata_validator'
require 'simple_forms_api_submission/s3'
require 'lgy/service'

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
        '40-0247' => 'vba_40_0247',
        '20-10206' => 'vba_20_10206',
        '40-10007' => 'vba_40_10007',
        '20-10207' => 'vba_20_10207'
      }.freeze

      IVC_FORM_NUMBER_MAP = {
        '10-10D' => 'vha_10_10d',
        '10-7959F-1' => 'vha_10_7959f_1',
        '10-7959F-2' => 'vha_10_7959f_2'
      }.freeze

      UNAUTHENTICATED_FORMS = %w[40-0247 21-10210 21P-0847 40-10007].freeze

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])

        response = if form_is210966 && icn && first_party?
                     handle_210966_authenticated
                   elsif form_is264555_and_should_use_lgy_api
                     handle264555
                   else
                     submit_form_to_central_mail
                   end

        clear_saved_form(params[:form_number])

        render response
      rescue Prawn::Errors::IncompatibleStringEncoding
        raise
      rescue => e
        raise Exceptions::ScrubbedUploadsSubmitError.new(params), e
      end

      def submit_supporting_documents
        if %w[40-0247 20-10207 10-10D 40-10007 10-7959F-2].include?(params[:form_id])
          attachment = PersistentAttachments::MilitaryRecords.new(form_id: params[:form_id])
          attachment.file = params['file']
          raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

          attachment.save
          render json: attachment
        end
      end

      def get_intents_to_file
        intent_service = SimpleFormsApi::IntentToFile.new(icn)
        existing_intents = intent_service.existing_intents

        render json: {
          compensation_intent: existing_intents['compensation'],
          pension_intent: existing_intents['pension'],
          survivor_intent: existing_intents['survivor']
        }
      end

      def authenticate
        super
      rescue Common::Exceptions::Unauthorized
        Rails.logger.info(
          'Simple forms api - unauthenticated user submitting form',
          { form_number: params[:form_number] }
        )
      end

      private

      def handle_210966_authenticated
        intent_service = SimpleFormsApi::IntentToFile.new(icn, params)
        form = SimpleFormsApi::VBA210966.new(JSON.parse(params.to_json))
        existing_intents = intent_service.existing_intents
        confirmation_number, expiration_date = intent_service.submit
        form.track_user_identity(confirmation_number)

        { json: {
          confirmation_number:,
          expiration_date:,
          compensation_intent: existing_intents['compensation'],
          pension_intent: existing_intents['pension'],
          survivor_intent: existing_intents['survivor']
        } }
      end

      def handle264555
        parsed_form_data = JSON.parse(params.to_json)
        form = SimpleFormsApi::VBA264555.new(parsed_form_data)
        lgy_response = LGY::Service.new.post_grant_application(payload: form.as_payload)
        reference_number = lgy_response.body['reference_number']
        status = lgy_response.body['status']
        { json: { reference_number:, status: }, status: lgy_response.status }
      end

      def submit_form_to_central_mail
        form_id = get_form_id
        parsed_form_data = JSON.parse(params.to_json)
        file_path, ivc_file_paths, metadata, form = get_file_paths_and_metadata(parsed_form_data)

        if IVC_FORM_NUMBER_MAP.value?(form_id)
          Datadog::Tracing.active_trace&.set_tag('ivc_form_id', form_id)
          status, error_message = handle_ivc_uploads(form_id, metadata, ivc_file_paths)
        else
          status, confirmation_number = upload_pdf_to_benefits_intake(file_path, metadata, form_id)
          form.track_user_identity(confirmation_number)

          Rails.logger.info(
            'Simple forms api - sent to benefits intake',
            { form_number: params[:form_number], status:, uuid: confirmation_number }
          )
        end

        if status == 200 && Flipper.enabled?(:simple_forms_email_confirmations)
          SimpleFormsApi::ConfirmationEmail.new(
            form_data: parsed_form_data, form_number: form_id, confirmation_number:, user: @current_user
          ).send
        end

        { json: get_json(confirmation_number || nil, form_id, error_message || nil), status: }
      end

      def handle_ivc_uploads(form_id, metadata, pdf_file_paths)
        meta_file_name = "#{form_id}_metadata.json"
        meta_file_path = "tmp/#{meta_file_name}"

        pdf_results =
          pdf_file_paths.map do |pdf_file_path|
            pdf_file_name = pdf_file_path.gsub('tmp/', '').gsub('-tmp', '')
            upload_to_ivc_s3(pdf_file_name, pdf_file_path, metadata)
          end

        all_pdf_success = pdf_results.all? { |(status, _)| status == 200 }

        if all_pdf_success
          File.write(meta_file_path, metadata)
          meta_upload_status, meta_upload_error_message = upload_to_ivc_s3(meta_file_name, meta_file_path)

          if meta_upload_status == 200
            FileUtils.rm_f(meta_file_path)
            [meta_upload_status, nil]
          else
            [meta_upload_status, meta_upload_error_message]
          end
        else
          [pdf_results]
        end
      end

      def get_file_paths_and_metadata(parsed_form_data)
        form_id = get_form_id
        form = "SimpleFormsApi::#{form_id.titleize.gsub(' ', '')}".constantize.new(parsed_form_data)
        filler = SimpleFormsApi::PdfFiller.new(form_number: form_id, form:)

        file_path = if @current_user
                      filler.generate(@current_user.loa[:current])
                    else
                      filler.generate
                    end
        metadata = SimpleFormsApiSubmission::MetadataValidator.validate(form.metadata,
                                                                        zip_code_is_us_based: form.zip_code_is_us_based)

        maybe_add_file_paths =
          case form_id
          when 'vba_40_0247', 'vba_20_10207', 'vha_10_10d', 'vba_40_10007', 'vha_10_7959f_2'
            form.handle_attachments(file_path)
          else
            [file_path]
          end

        [file_path, maybe_add_file_paths, metadata, form]
      end

      def get_upload_location_and_uuid(lighthouse_service, form_id)
        upload_location = lighthouse_service.get_upload_location.body
        if form_id == 'vba_40_10007'
          uuid = upload_location.dig('data', 'id')
          SimpleFormsApi::PdfStamper.stamp4010007_uuid(uuid)
        end
        {
          uuid: upload_location.dig('data', 'id'),
          location: upload_location.dig('data', 'attributes', 'location')
        }
      end

      def upload_to_ivc_s3(file_name, file_path, metadata = {})
        case ivc_s3_client.put_object(file_name, file_path, metadata)
        in { success: true }
          [200]
        in { success: false, error_message: error_message }
          [400, error_message]
        else
          [500, 'Unexpected response from S3 upload']
        end
      end

      def upload_pdf_to_benefits_intake(file_path, metadata, form_id)
        lighthouse_service = SimpleFormsApiSubmission::Service.new
        uuid_and_location = get_upload_location_and_uuid(lighthouse_service, form_id)
        form_submission = FormSubmission.create(
          form_type: params[:form_number],
          benefits_intake_uuid: uuid_and_location[:uuid],
          form_data: params.to_json,
          user_account: @current_user&.user_account
        )
        FormSubmissionAttempt.create(form_submission:)

        Datadog::Tracing.active_trace&.set_tag('uuid', uuid_and_location[:uuid])
        Rails.logger.info(
          'Simple forms api - preparing to upload PDF to benefits intake',
          { location: uuid_and_location[:location], uuid: uuid_and_location[:uuid] }
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

      def form_is264555_and_should_use_lgy_api
        # TODO: Remove comment octothorpe and ALWAYS require icn
        params[:form_number] == '26-4555' # && icn
      end

      def should_authenticate
        true unless UNAUTHENTICATED_FORMS.include? params[:form_number]
      end

      def icn
        @current_user&.icn
      end

      def first_party?
        params[:preparer_identification] == 'VETERAN'
      end

      def get_form_id
        form_number = params[:form_number]
        raise 'missing form_number in params' unless form_number

        if IVC_FORM_NUMBER_MAP.key?(form_number)
          IVC_FORM_NUMBER_MAP[form_number]
        else
          FORM_NUMBER_MAP[form_number]
        end
      end

      def get_json(confirmation_number, form_id, error_message)
        json = { confirmation_number: }
        json[:expiration_date] = 1.year.from_now if form_id == 'vba_21_0966'
        json[:error_message] = error_message

        json
      end

      def ivc_s3_client
        @ivc_s3_client ||= SimpleFormsApiSubmission::S3.new(
          region: Settings.ivc_forms.s3.region,
          access_key_id: Settings.ivc_forms.s3.aws_access_key_id,
          secret_access_key: Settings.ivc_forms.s3.aws_secret_access_key,
          bucket_name: Settings.ivc_forms.s3.bucket
        )
      end
    end
  end
end
