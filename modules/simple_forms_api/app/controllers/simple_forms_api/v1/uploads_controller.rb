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

      UNAUTHENTICATED_FORMS = %w[40-0247 21-10210 21P-0847 40-10007].freeze

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])

        response = if intent_service.use_intent_api?
                     handle_210966_authenticated
                   elsif form_is264555_and_should_use_lgy_api
                     handle264555
                   else
                     benefits_intake_client = SimpleFormsApi::BenefitsIntakeClient.new(@current_user, params)
                     benefits_intake_client.submit_form
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

      def form_is264555_and_should_use_lgy_api
        params[:form_number] == '26-4555' && icn
      end

      def icn
        @current_user&.icn
      end

      def fetch_form_id
        form_number = params[:form_number]
        raise 'missing form_number in params' unless form_number

        SimpleFormsApi::BenefitsIntakeClient::FORM_NUMBER_MAP[form_number]
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
