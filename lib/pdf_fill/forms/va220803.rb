# frozen_string_literal: true

module PdfFill
  module Forms
    class Va220803 < FormBase
      include FormHelper

      AGREEMENT_TYPES = {
        'startNewOpenEndedAgreement' => 'New open-ended agreement',
        'modifyExistingAgreement' => 'Modification to existing agreement',
        'withdrawFromYellowRibbonProgram' => 'Withdrawal of Yellow Ribbon agreement'
      }.freeze

      KEY = {
        'bill_type_chapter_30' => {
          key: 'bill_type_chapter_30'
        },
        'bill_type_chapter_33' => {
          key: 'bill_type_chapter_33'
        },
        'bill_type_chapter_35' => {
          key: 'bill_type_chapter_35'
        },
        'bill_type_chapter_1606' => {
          key: 'bill_type_chapter_1606'
        },
        'applicantName' => {
          key: 'applicant_name'
        },
        'remarks' => {
          key: 'remarks'
        },
        'mailingAddress' => {
          key: 'applicant_address'
        },
        'emailAddress' => {
          key: 'applicant_email'
        },
        'fileNumber' => {
          key: 'applicant_va_file_number'
        },
        'mobilePhone' => {
          key: 'applicant_mobile_phone'
        },
        'homePhone' => {
          key: 'applicant_home_phone'
        },
        'previously_applied_yes' => {
          key: 'previously_applied_yes'
        },
        'previously_applied_no' => {
          key: 'previously_applied_no'
        },
        'testName' => {
          key: 'test_name'
        },
        'testDate' => {
          key: 'test_date'
        },
        'testCost' => {
          key: 'test_cost'
        },
        'organizationInfo' => {
          key: 'certifying_name_and_address'
        },
        'statementOfTruthSignature' => {
          key: 'applicant_signature'
        },
        'dateSigned' => {
          key: 'date_signed'
        }
      }.freeze

      def merge_fields(_options = {})
        form_data = JSON.parse(JSON.generate(@form_data))

        form_data['applicantName'] = combine_full_name(form_data['applicantName'])
        form_data['mailingAddress'] = combine_full_address_extras(form_data['mailingAddress'])
        format_bill_type(form_data)
        format_file_number(form_data)
        format_previously_applied(form_data)
        format_organization_info(form_data)

        form_data
      end

      def format_bill_type(form_data)
        case form_data['vaBenefitProgram']
        when 'chapter30'
          form_data['bill_type_chapter_30'] = 'Yes'
        when 'chapter33'
          form_data['bill_type_chapter_33'] = 'Yes'
        when 'chapter35'
          form_data['bill_type_chapter_35'] = 'Yes'
        when 'chapter1606'
          form_data['bill_type_chapter_1606'] = 'Yes'
        end
      end

      def format_file_number(form_data)
        if form_data['vaFileNumber'].present? && form_data['vaBenefitProgram'] == 'chapter35'
          formatted_file_number = [form_data['vaFileNumber'][0..2],
                                   form_data['vaFileNumber'][3..4],
                                   form_data['vaFileNumber'][5..]].join('-')
          form_data['fileNumber'] = "#{formatted_file_number} #{form_data['payeeNumber']}"
        else
          form_data['fileNumber'] = ''
        end
      end

      def format_previously_applied(form_data)
        if form_data['hasPreviouslyApplied']
          form_data['previously_applied_yes'] = 'Yes'
        else
          form_data['previously_applied_no'] = 'Yes'
        end
      end

      def format_organization_info(form_data)
        form_data['organizationInfo'] = <<~ORGINFO
          #{form_data['organizationName']}
          #{combine_full_address_extras(form_data['organizationAddress'])}
        ORGINFO
      end
    end
  end
end
