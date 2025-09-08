# frozen_string_literal: true

module PdfFill
  module Forms
    class Va228794 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'designatingOfficial' => {
          'fullName' => {
            'first' => {
              key: 'form1[0].#subform[6].REMARKS[0]'
            }
          }
        }
      }.freeze

      def merge_fields(_options = {})
        # merge_veteran_helpers

        # expand_signature(@form_data['dependencyVerification']['veteranInformation']['fullName'])
        # @form_data['dateSigned'] = split_date(@form_data['signatureDate'])

        @form_data
      end

      # def merge_veteran_helpers
      #   veteran_information = @form_data['dependencyVerification']['veteranInformation']
      #   # extract middle initial
      #   veteran_information['fullName'] = extract_middle_i(veteran_information, 'fullName')

      #   # extract ssn
      #   ssn = veteran_information['ssn']
      #   veteran_information['ssn'] = split_ssn(ssn.delete('-')) if ssn.present?
      #   veteran_information['ssn2'] = split_ssn(ssn.delete('-')) if ssn.present?

      #   # extract birth date
      #   veteran_information['dateOfBirth'] = split_date(veteran_information['dateOfBirth'])

      #   # extract email address
      #   extract_email

      #   # this is confusing but if updateDiaries is set to true
      #   # that means the status of the dependents has NOT changed
      #   update_diaries = @form_data['dependencyVerification']['updateDiaries']
      #   @form_data['dependencyVerification']['updateDiaries'] = {
      #     'status_changed_yes' => select_checkbox(!update_diaries),
      #     'status_changed_no' => select_checkbox(update_diaries)
      #   }
      # end

      # def extract_email
      #   email_address = @form_data['dependencyVerification']['veteranInformation']['email']
      #   return if email_address.blank?

      #   if email_address.length > 17 && email_address.length < 37
      #     @form_data['dependencyVerification']['email1'] = email_address[0..17]
      #     @form_data['dependencyVerification']['email2'] = email_address[18..]
      #   else
      #     @form_data['dependencyVerification']['email1'] = email_address
      #   end
      # end
    end
  end
end
