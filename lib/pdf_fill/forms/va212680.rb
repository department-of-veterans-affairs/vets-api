# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'

module PdfFill
  module Forms
    class Va212680 < FormBase
      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        # Section I: Veteran Information
        'veteranInformation' => {
          'fullName' => {
            'first' => {
              key: 'form1[0].#subform[0].VeteransFirstName[0]',
              limit: 12,
              question_num: 1,
              question_suffix: 'A',
              question_text: "VETERAN'S FIRST NAME"
            },
            'middle' => {
              key: 'form1[0].#subform[0].VeteransMiddleInitial[0]',
              limit: 1
            },
            'last' => {
              key: 'form1[0].#subform[0].VeteransLastName[0]',
              limit: 18,
              question_num: 1,
              question_suffix: 'B',
              question_text: "VETERAN'S LAST NAME"
            }
          },
          'ssn' => {
            key: 'form1[0].#subform[0].SocialSecurityNumber[0]',
            limit: 9,
            question_num: 2,
            question_text: 'SOCIAL SECURITY NUMBER'
          },
          'vaFileNumber' => {
            key: 'form1[0].#subform[0].VAFileNumber[0]',
            limit: 9,
            question_num: 3,
            question_text: 'VA FILE NUMBER'
          },
          'dateOfBirth' => {
            key: 'form1[0].#subform[0].DateOfBirth[0]',
            question_num: 4,
            question_text: 'DATE OF BIRTH'
          }
        },

        # Section II: Claimant Information
        'claimantInformation' => {
          'fullName' => {
            'first' => {
              key: 'form1[0].#subform[0].ClaimantFirstName[0]',
              limit: 12,
              question_num: 5,
              question_suffix: 'A',
              question_text: "CLAIMANT'S FIRST NAME"
            },
            'middle' => {
              key: 'form1[0].#subform[0].ClaimantMiddleInitial[0]',
              limit: 1
            },
            'last' => {
              key: 'form1[0].#subform[0].ClaimantLastName[0]',
              limit: 18,
              question_num: 5,
              question_suffix: 'B',
              question_text: "CLAIMANT'S LAST NAME"
            }
          },
          'relationship' => {
            key: 'form1[0].#subform[0].RelationshipToVeteran[0]',
            limit: 30,
            question_num: 6,
            question_text: 'RELATIONSHIP TO VETERAN'
          },
          'address' => {
            'street' => {
              key: 'form1[0].#subform[0].MailingAddress_Street[0]',
              limit: 30,
              question_num: 7,
              question_suffix: 'A',
              question_text: 'MAILING ADDRESS - STREET'
            },
            'city' => {
              key: 'form1[0].#subform[0].MailingAddress_City[0]',
              limit: 18,
              question_num: 7,
              question_suffix: 'B',
              question_text: 'CITY'
            },
            'state' => {
              key: 'form1[0].#subform[0].MailingAddress_State[0]',
              limit: 2,
              question_num: 7,
              question_suffix: 'C',
              question_text: 'STATE'
            },
            'zipCode' => {
              key: 'form1[0].#subform[0].MailingAddress_ZIPCode[0]',
              limit: 10,
              question_num: 7,
              question_suffix: 'D',
              question_text: 'ZIP CODE'
            }
          }
        },

        # Section III: Benefit Information
        'benefitInformation' => {
          'claimType' => {
            key: 'form1[0].#subform[0].ClaimType[0]',
            limit: 50,
            question_num: 8,
            question_text: 'TYPE OF CLAIM (Aid and Attendance or Housebound)'
          }
        },

        # Section IV: Additional Information
        'additionalInformation' => {
          'currentlyHospitalized' => {
            key: 'form1[0].#subform[0].CurrentlyHospitalized[0]',
            question_num: 9,
            question_suffix: 'A',
            question_text: 'IS VETERAN CURRENTLY HOSPITALIZED'
          },
          'nursingHome' => {
            key: 'form1[0].#subform[0].NursingHome[0]',
            question_num: 9,
            question_suffix: 'B',
            question_text: 'IS VETERAN IN A NURSING HOME'
          }
        },

        # Section V: Veteran Signature
        'veteranSignature' => {
          'signature' => {
            key: 'form1[0].#subform[0].VeteranSignature[0]',
            limit: 30,
            question_num: 10,
            question_suffix: 'A',
            question_text: 'VETERAN OR CLAIMANT SIGNATURE'
          },
          'date' => {
            key: 'form1[0].#subform[0].SignatureDate[0]',
            question_num: 10,
            question_suffix: 'B',
            question_text: 'DATE SIGNED'
          }
        }

        # NOTE: Sections VI-VIII (Physician sections) are intentionally left blank
        # These will be filled out manually by the physician on the printed form
      }.freeze

      def merge_fields(options = {})
        @pdf_data ||= {}
        merge_veteran_information
        merge_claimant_information
        merge_benefit_information
        merge_additional_information
        merge_veteran_signature

        @pdf_data
      end

      private

      def merge_veteran_information
        veteran_info = @form_data['veteranInformation']
        return unless veteran_info

        # Merge name fields
        if veteran_info['fullName']
          @pdf_data['form1[0].#subform[0].VeteransFirstName[0]'] = veteran_info['fullName']['first']
          @pdf_data['form1[0].#subform[0].VeteransMiddleInitial[0]'] = veteran_info['fullName']['middle']
          @pdf_data['form1[0].#subform[0].VeteransLastName[0]'] = veteran_info['fullName']['last']
        end

        # Merge SSN (formatted without dashes)
        @pdf_data['form1[0].#subform[0].SocialSecurityNumber[0]'] =
          veteran_info['ssn']&.gsub(/\D/, '')

        # Merge VA file number
        @pdf_data['form1[0].#subform[0].VAFileNumber[0]'] = veteran_info['vaFileNumber']

        # Merge date of birth
        @pdf_data['form1[0].#subform[0].DateOfBirth[0]'] =
          format_date(veteran_info['dateOfBirth'])
      end

      def merge_claimant_information
        claimant_info = @form_data['claimantInformation']
        return unless claimant_info

        # Merge name fields
        if claimant_info['fullName']
          @pdf_data['form1[0].#subform[0].ClaimantFirstName[0]'] = claimant_info['fullName']['first']
          @pdf_data['form1[0].#subform[0].ClaimantMiddleInitial[0]'] = claimant_info['fullName']['middle']
          @pdf_data['form1[0].#subform[0].ClaimantLastName[0]'] = claimant_info['fullName']['last']
        end

        # Merge relationship
        @pdf_data['form1[0].#subform[0].RelationshipToVeteran[0]'] = claimant_info['relationship']

        # Merge address
        if claimant_info['address']
          address = claimant_info['address']
          @pdf_data['form1[0].#subform[0].MailingAddress_Street[0]'] = address['street']
          @pdf_data['form1[0].#subform[0].MailingAddress_City[0]'] = address['city']
          @pdf_data['form1[0].#subform[0].MailingAddress_State[0]'] = address['state']
          @pdf_data['form1[0].#subform[0].MailingAddress_ZIPCode[0]'] = address['zipCode']
        end
      end

      def merge_benefit_information
        benefit_info = @form_data['benefitInformation']
        return unless benefit_info

        @pdf_data['form1[0].#subform[0].ClaimType[0]'] = benefit_info['claimType']
      end

      def merge_additional_information
        additional_info = @form_data['additionalInformation']
        return unless additional_info

        # Convert boolean values to Yes/No or checkboxes as appropriate for the PDF
        @pdf_data['form1[0].#subform[0].CurrentlyHospitalized[0]'] =
          boolean_to_checkbox(additional_info['currentlyHospitalized'])

        @pdf_data['form1[0].#subform[0].NursingHome[0]'] =
          boolean_to_checkbox(additional_info['nursingHome'])
      end

      def merge_veteran_signature
        signature_info = @form_data['veteranSignature']
        return unless signature_info

        @pdf_data['form1[0].#subform[0].VeteranSignature[0]'] = signature_info['signature']
        @pdf_data['form1[0].#subform[0].SignatureDate[0]'] =
          format_date(signature_info['date'])
      end

      def format_date(date_string)
        return nil if date_string.blank?

        date = Date.parse(date_string.to_s)
        date.strftime('%m/%d/%Y')
      rescue ArgumentError
        date_string
      end

      def boolean_to_checkbox(value)
        case value
        when true
          'Yes'
        when false
          'No'
        else
          ''
        end
      end
    end
  end
end
