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
        response = submission.submit

        render json: response, status: :unprocessable_entity if response[:error]

        render json: response
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

      def submission
        if intent_service.use_intent_api?
          IntentToFile::Submission.new(@current_user, params)
        elsif LGY::Submission::LGY_API_FORMS.include?(params[:form_number])
          LGY::Submission.new(@current_user, params)
        else
          BenefitsIntake::Submission.new(@current_user, params)
        end
      end
    end
  end
end
