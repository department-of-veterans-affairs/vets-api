# frozen_string_literal: true

module SimpleFormsApi
  module Notification
    class Personalization
      attr_reader :first_name, :form, :date_submitted, :confirmation_number, :lighthouse_updated_at, :expiration_date

      def initialize(form:, config:, expiration_date: nil)
        @first_name = form.notification_first_name&.titleize
        @date_submitted = config[:date_submitted]
        @confirmation_number = config[:confirmation_number]
        @lighthouse_updated_at = config[:lighthouse_updated_at]
        @form = form
        @expiration_date = expiration_date
      end

      def to_hash
        if first_name && date_submitted
          {
            'first_name' => first_name,
            'date_submitted' => date_submitted
          }.tap do |personalization|
            personalization['lighthouse_updated_at'] = lighthouse_updated_at if lighthouse_updated_at
            personalization['confirmation_number'] = confirmation_number if confirmation_number
            personalization.merge!(form21_0966_personalization) if form.instance_of? SimpleFormsApi::VBA210966

            if form.should_send_to_point_of_contact?
              personalization.merge!(
                'poc_first_name_last_name' => form.notification_point_of_contact_name,
                'last_name' => form.notification_last_name
              )
            end
          end
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
        benefits = form.data['benefit_selection']
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
