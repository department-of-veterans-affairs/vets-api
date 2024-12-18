# frozen_string_literal: true

module SimpleFormsApi
  module IntentToFile
    class Submission
      def initialize(current_user, params)
        @current_user = current_user
        @params = params
      end

      def submit
        parsed_form_data = JSON.parse(@params.to_json)
        confirmation_number, expiration_date = intent_service.submit

        track_user_identity(confirmation_number)

        if confirmation_number && email_confirmation_enabled?
          send_confirmation_email(parsed_form_data, confirmation_number, expiration_date)
        end

        build_response(confirmation_number, expiration_date)
      rescue Common::Exceptions::UnprocessableEntity, Exceptions::BenefitsClaimsApiDownError => e
        handle_submission_error(e)
      end

      private

      attr_reader :current_user, :params

      def intent_service
        @intent_service ||= SimpleFormsApi::SupportingForms::IntentToFile.new(@current_user, params)
      end

      def track_user_identity(confirmation_number)
        return unless confirmation_number

        SimpleFormsApi::VBA210966.new(parsed_form_data).track_user_identity(confirmation_number)
      end

      def email_confirmation_enabled?
        Flipper.enabled?(:simple_forms_email_confirmations)
      end

      def build_response(confirmation_number, expiration_date)
        {
          json: {
            confirmation_number: confirmation_number,
            expiration_date: expiration_date,
            compensation_intent: intent_service.existing_intents['compensation'],
            pension_intent: intent_service.existing_intents['pension'],
            survivor_intent: intent_service.existing_intents['survivor']
          }
        }
      end

      def handle_submission_error(error)
        prepare_params_for_benefits_intake
        log_error(error)
        SimpleFormsApi::BenefitsIntake::Submission.new(current_user, params).submit
      end

      def prepare_params_for_benefits_intake
        params['veteran_full_name'] ||= {
          'first' => params['full_name']['first'],
          'last' => params['full_name']['last']
        }
        params['veteran_id'] ||= { 'ssn' => params['ssn'] }
        params['veteran_mailing_address'] ||= { 'postal_code' => current_user.address[:postal_code] || '00000' }
      end

      def log_error(error)
        Rails.logger.info(
          'Simple forms api - 21-0966 Benefits Claims Intent to File API error, reverting to filling a PDF and sending it to Benefits Intake API',
          {
            error: error,
            is_current_user_participant_id_present: current_user.participant_id.present?,
            current_user_account_uuid: current_user.user_account_uuid
          }
        )
      end

      def send_confirmation_email(parsed_form_data, confirmation_number, expiration_date)
        config = {
          form_data: parsed_form_data,
          form_number: 'vba_21_0966_intent_api',
          confirmation_number: confirmation_number,
          date_submitted: Time.zone.today.strftime('%B %d, %Y'),
          expiration_date: expiration_date
        }
        notification_email = SimpleFormsApi::NotificationEmail.new(
          config,
          notification_type: :received,
          user: current_user
        )
        notification_email.send
      end
    end
  end
end
