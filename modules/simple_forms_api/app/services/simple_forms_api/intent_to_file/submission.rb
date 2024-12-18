# frozen_string_literal: true

module SimpleFormsApi
  module IntentToFile
    module Submission
      def initialize(current_user, params)
        @current_user = current_user
        @params = params
      end

      def submit
        parsed_form_data = JSON.parse(params.to_json)
        form = SimpleFormsApi::VBA210966.new(parsed_form_data)
        existing_intents = intent_service.existing_intents
        confirmation_number, expiration_date = intent_service.submit
        form.track_user_identity(confirmation_number)

        if confirmation_number && Flipper.enabled?(:simple_forms_email_confirmations)
          send_intent_received_email(parsed_form_data, confirmation_number, expiration_date)
        end

        response_json(confirmation_number, expiration_date, existing_intents)
      rescue Common::Exceptions::UnprocessableEntity, Exceptions::BenefitsClaimsApiDownError => e
        # Common::Exceptions::UnprocessableEntity: There is an authentication issue with the Intent to File API
        # Exceptions::BenefitsClaimsApiDownError: The Intent to File API is down or timed out
        # In either case, we revert to sending a PDF to Central Mail through the Benefits Intake API
        prepare_params_for_benefits_intake_and_log_error(e)
        SimpleFormsApi::BenefitsIntake::Submission.new(@current_user, params).submit
      end

      private

      attr_accessor :current_user, :params

      def intent_service
        @intent_service ||= SimpleFormsApi::SupportingForms::IntentToFile.new(@current_user, params)
      end

      def send_intent_received_email(parsed_form_data, confirmation_number, expiration_date)
        config = {
          form_data: parsed_form_data,
          form_number: 'vba_21_0966_intent_api',
          confirmation_number:,
          date_submitted: Time.zone.today.strftime('%B %d, %Y'),
          expiration_date:
        }
        notification_email = SimpleFormsApi::NotificationEmail.new(
          config,
          notification_type: :received,
          user: @current_user
        )
        notification_email.send
      end

      def response_json(confirmation_number, expiration_date, existing_intents)
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
    end
  end
end
