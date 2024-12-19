# frozen_string_literal: true

require 'ddtrace'
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

        response = submission.submit
        clear_saved_form(params[:form_number])

        render response
      rescue Prawn::Errors::IncompatibleStringEncoding
        raise
      rescue => e
        raise Exceptions::ScrubbedUploadsSubmitError.new(params), e
      end

      def submit_supporting_documents
        return unless SupportingDocuments::Submission::FORMS_WITH_SUPPORTING_DOCUMENTS.include?(params[:form_id])

        submission = SupportingDocuments::Submission.new(@current_user, params)
        submission.submit
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
        @intent_service ||= SupportingForms::IntentToFile.new(@current_user, params)
      end

      def skip_authentication?
        UNAUTHENTICATED_FORMS.include?(params[:form_number]) || UNAUTHENTICATED_FORMS.include?(params[:form_id])
      end

      def submit_intent_to_file
        submission = SimpleFormsApi::IntentToFile::Submission.new(@current_user, params)
        submission.submit
      end

      def submit_form_to_benefits_intake
        submission = SimpleFormsApi::BenefitsIntake::Submission.new(@current_user, params)
        submission.submit
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

        if Flipper.enabled?(:simple_forms_email_confirmations)
          case status
          when 'VALIDATED', 'ACCEPTED'
            send_sahsha_email(parsed_form_data, reference_number, :confirmation)
          when 'REJECTED'
            send_sahsha_email(parsed_form_data, reference_number, :rejected)
          when 'DUPLICATE'
            send_sahsha_email(parsed_form_data, reference_number, :duplicate)
          end
        end

        { json: { reference_number:, status: }, status: lgy_response.status }
      end

      def form_is264555_and_should_use_lgy_api
        params[:form_number] == '26-4555' && @current_user&.icn
      end

      def submission
        if intent_service.use_intent_api?
          IntentToFile::Submission.new(@current_user, params)
        elsif LGY::Submission::LGY_API_FORMS.include?(params[:form_number])
          LGY::Submission.new(@current_user, params)
        else
          BenefitsIntake::Submission.new(@current_user, params)
        end
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

      def send_sahsha_email(parsed_form_data, confirmation_number, notification_type)
        config = {
          form_data: parsed_form_data,
          form_number: 'vba_26_4555',
          confirmation_number:,
          date_submitted: Time.zone.today.strftime('%B %d, %Y')
        }
        notification_email = SimpleFormsApi::NotificationEmail.new(
          config,
          notification_type:,
          user: @current_user
        )
        notification_email.send
      end
    end
  end
end
