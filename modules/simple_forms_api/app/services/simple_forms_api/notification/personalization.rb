# frozen_string_literal: true

module SimpleFormsApi
  module Notification
    class Personalization
      attr_reader :first_name, :form, :date_submitted, :confirmation_number, :lighthouse_updated_at, :expiration_date

      def initialize(form:, form_submission_attempt:, expiration_date: nil)
        @first_name = form.notification_first_name&.titleize
        @form = form
        @date_submitted = form_submission_attempt.created_at.strftime('%B %d, %Y')
        @confirmation_number = form_submission_attempt.benefits_intake_uuid
        @lighthouse_updated_at = form_submission_attempt.lighthouse_updated_at&.strftime('%B %d, %Y')
        @expiration_date = expiration_date
      end

      def to_hash
        {
          'first_name' => first_name,
          'date_submitted' => date_submitted
        }.tap do |personalization|
          personalization['lighthouse_updated_at'] = lighthouse_updated_at if lighthouse_updated_at
          personalization['confirmation_number'] = confirmation_number if confirmation_number
          personalization.merge(form21_0966_personalization) if form.instance_of? SimpleFormsApi::VBA210966
        end
      end

      private

      def form21_0966_personalization
        intent_to_file_benefits, intent_to_file_benefits_links = get_intent_to_file_benefits_variables
        {
          'intent_to_file_benefits' => intent_to_file_benefits,
          'intent_to_file_benefits_links' => intent_to_file_benefits_links,
          'itf_api_expiration_date' => expiration_date
        }
      end

      def get_intent_to_file_benefits_variables
        benefits = form_data['benefit_selection']
        if benefits['compensation'] && benefits['pension']
          ['disability compensation and Veterans pension benefits',
           '[File for disability compensation (VA Form 21-526EZ)]' \
           '(https://www.va.gov/disability/file-disability-claim-form-21-526ez/introduction) and [Apply for Veterans ' \
           'Pension benefits (VA Form 21P-527EZ)](https://www.va.gov/find-forms/about-form-21p-527ez/)']
        elsif benefits['compensation']
          ['disability compensation',
           '[File for disability compensation (VA Form 21-526EZ)](https://www.va.gov/disability/file-disability-claim-form-21-526ez/introduction)']
        elsif benefits['pension']
          ['Veterans pension benefits',
           '[Apply for Veterans Pension benefits (VA Form 21P-527EZ)](https://www.va.gov/find-forms/about-form-21p-527ez/)']
        elsif benefits['survivor']
          ['survivors pension benefits',
           '[Apply for DIC, Survivors Pension, and/or Accrued Benefits (VA Form 21P-534EZ)](https://www.va.gov/find-forms/about-form-21p-534ez/)']
        end
      end
    end
  end
end
